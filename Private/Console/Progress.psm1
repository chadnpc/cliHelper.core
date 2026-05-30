using namespace System
using namespace System.Collections.Generic
using namespace System.Threading
using namespace System.Threading.Tasks

using module ..\Enums.psm1
using module ..\Abstracts.psm1
using module .\Colors.psm1
using module .\Internal.psm1
using module .\Rendering.psm1
using module .\Ansi.psm1
using module .\Spinners.psm1
using module .\Layout.psm1
using module .\Widgets.psm1

class ProgressTaskState {
  [object]$SyncRoot
  [int]$Id
  [string]$Description
  [double]$Value
  [double]$MaxValue
  [bool]$IsIndeterminate
  [bool]$IsCompleted
  [DateTime]$StartedAt
  [Nullable[DateTime]]$StoppedAt

  [bool] get_IsStarted() { return $this.StartedAt -ne [DateTime]::MinValue }
  [bool] get_IsFinished() { return $this.IsCompleted }

  ProgressTaskState([int]$id, [string]$description, [double]$maxValue) {
    $this.SyncRoot = [object]::new()
    $this.Id = $id
    $this.Description = $description
    $this.Value = 0
    $this.MaxValue = [Math]::Max(1, $maxValue)
    $this.IsIndeterminate = $false
    $this.IsCompleted = $false
    $this.StartedAt = [DateTime]::UtcNow
  }

  [double] Percent() {
    [Monitor]::Enter($this.SyncRoot)
    try {
      if ($this.IsIndeterminate) { return 0 }
      return [Math]::Min(100, ($this.Value / $this.MaxValue) * 100)
    } finally {
      [Monitor]::Exit($this.SyncRoot)
    }
  }

  [ProgressTaskState] Snapshot() {
    [Monitor]::Enter($this.SyncRoot)
    try {
      $copy = [ProgressTaskState]::new($this.Id, $this.Description, $this.MaxValue)
      $copy.Value = $this.Value
      $copy.IsIndeterminate = $this.IsIndeterminate
      $copy.IsCompleted = $this.IsCompleted
      $copy.StartedAt = $this.StartedAt
      $copy.StoppedAt = $this.StoppedAt
      return $copy
    } finally {
      [Monitor]::Exit($this.SyncRoot)
    }
  }
}

class ProgressTask {
  hidden [ProgressTaskState]$_state
  [Action]$OnUpdate

  ProgressTask([ProgressTaskState]$state) { $this._state = $state }

  hidden [void] TriggerUpdate() {
    if ($null -ne $this.OnUpdate) {
      $this.OnUpdate.Invoke()
    }
  }

  [ProgressTaskState] GetState() { return $this._state.Snapshot() }

  [void] Increment([double]$delta) {
    [Monitor]::Enter($this._state.SyncRoot)
    try {
      $this._state.Value = [Math]::Min($this._state.MaxValue, $this._state.Value + $delta)
      if ($this._state.Value -ge $this._state.MaxValue) {
        $this._state.IsCompleted = $true
        $this._state.StoppedAt = [DateTime]::UtcNow
      }
    } finally {
      [Monitor]::Exit($this._state.SyncRoot)
    }
    $this.TriggerUpdate()
  }

  [void] SetValue([double]$value) {
    [Monitor]::Enter($this._state.SyncRoot)
    try {
      $this._state.Value = [Math]::Max(0, [Math]::Min($this._state.MaxValue, $value))
      if ($this._state.Value -ge $this._state.MaxValue) {
        $this._state.IsCompleted = $true
        $this._state.StoppedAt = [DateTime]::UtcNow
      }
    } finally {
      [Monitor]::Exit($this._state.SyncRoot)
    }
    $this.TriggerUpdate()
  }

  [void] SetDescription([string]$description) {
    [Monitor]::Enter($this._state.SyncRoot)
    try {
      $this._state.Description = $description
    } finally {
      [Monitor]::Exit($this._state.SyncRoot)
    }
    $this.TriggerUpdate()
  }

  [void] Start() {
    [Monitor]::Enter($this._state.SyncRoot)
    try {
      $this._state.StartedAt = [DateTime]::UtcNow
      $this._state.IsCompleted = $false
      $this._state.StoppedAt = $null
    } finally {
      [Monitor]::Exit($this._state.SyncRoot)
    }
    $this.TriggerUpdate()
  }

  [void] Complete() {
    [Monitor]::Enter($this._state.SyncRoot)
    try {
      $this._state.Value = $this._state.MaxValue
      $this._state.IsCompleted = $true
      $this._state.StoppedAt = [DateTime]::UtcNow
    } finally {
      [Monitor]::Exit($this._state.SyncRoot)
    }
    $this.TriggerUpdate()
  }
}

class ProgressConfig : RenderOptions {
  [RGB]$ProgressBarColor
  [RGB]$ProgressMsgColor
  [string]$ProgressBlock
  ProgressConfig() : base() { $this.Reset() }
  ProgressConfig($hashtable) { $this.Reset() }
  ProgressConfig([hashtable[]]$array): base($array) { $this.Reset() }
  [void] Reset() {
    $this.ProgressBarColor = "LightSeaGreen"
    $this.ProgressMsgColor = "LightGoldenrodYellow"
    $this.ProgressBlock = '■'
    $this.PsObject.Properties.Add([PSscriptProperty]::new("ShowProgress", { return (Get-Variable 'VerbosePreference' -ValueOnly) -eq 'Continue' }))
  }
  # Returns [ProgressConfig] but declared as [RenderOptions] to avoid PS class self-referential return type parse error.
  static [RenderOptions] Create([object]$writer, [object]$capabilities) {
    $cfg = [ProgressConfig]::new()
    if ($null -ne $capabilities) {
      $cfg.ColorSystem = $capabilities.ColorSystem
      $cfg.Ansi = $capabilities.Ansi
    }
    return $cfg
  }
  [RenderOptions] ToRenderOptions() {
    # copy all base properties
    $o = [RenderOptions]@{}

    # CRITICAL BUG FIX PRESERVATION (#1 PowerShell ETS):
    # This loop MUST iterate over $o.PsObject.Properties, NOT $this!
    # $this (ProgressConfig) dynamically injects PSScriptProperties like 'ShowProgress'.
    # Iterating over $this would attempt to assign these to $o, aborting the timer thread.
    foreach ($name in $o.PsObject.Properties.Name) {
      $o.$name = $this.$name
    }
    return $o
  }
}

class ProgressTaskSettings : PsRecord {
  [double]$MaxValue = 100
  [bool]$AutoStart = $true
  [bool]$IsIndeterminate = $false

  ProgressTaskSettings() : base() {}
  ProgressTaskSettings($hashtable): base($hashtable) {}
  ProgressTaskSettings([hashtable[]]$array): base($array) {}
}

class ProgressContext : PsRecord {
  hidden [List[ProgressTaskState]]$_tasks = [List[ProgressTaskState]]::new()
  hidden [int]$_nextId = 1
  hidden [object]$_syncRoot = [object]::new()
  [Action]$OnUpdate

  ProgressContext() : base() {}
  ProgressContext($hashtable): base($hashtable) {}
  ProgressContext([hashtable[]]$array): base($array) {}

  [ProgressTask] AddTask([string]$description, [ProgressTaskSettings]$settings) {
    if ($null -eq $settings) { $settings = [ProgressTaskSettings]::new() }

    [Monitor]::Enter($this._syncRoot)
    try {
      $state = [ProgressTaskState]::new($this._nextId, $description, $settings.MaxValue)
      $state.IsIndeterminate = $settings.IsIndeterminate
      if (!$settings.AutoStart) {
        $state.StartedAt = [DateTime]::MinValue
      }
      $this._tasks.Add($state)
      $this._nextId++
      $task = [ProgressTask]::new($state)
      $task.OnUpdate = $this.OnUpdate
      return $task
    } finally {
      [Monitor]::Exit($this._syncRoot)
    }
  }

  [ProgressTaskState[]] GetTasks() {
    [Monitor]::Enter($this._syncRoot)
    try {
      $snapshot = [List[ProgressTaskState]]::new()
      foreach ($task in $this._tasks) {
        $snapshot.Add($task.Snapshot())
      }
      return $snapshot.ToArray()
    } finally {
      [Monitor]::Exit($this._syncRoot)
    }
  }

  [bool] IsFinished() {
    foreach ($task in $this.GetTasks()) {
      if (!$task.IsCompleted -and !$task.IsIndeterminate) { return $false }
    }
    return $true
  }
}

class LiveDisplayRegion : IDisposable {
  hidden [AnsiWriter]$_writer
  hidden [object]$_syncRoot
  hidden [int]$_lineCount
  hidden [bool]$_cursorHidden
  hidden [bool]$_supportsAnsi

  LiveDisplayRegion([AnsiWriter]$writer) {
    $this._writer = $writer
    $this._syncRoot = [object]::new()
    $this._lineCount = 0
    $this._cursorHidden = $false
    $this._supportsAnsi = $writer.Capabilities.Ansi
  }

  [void] Begin() {
    if ($this._supportsAnsi -and !$this._cursorHidden) {
      $this._writer.Write("`e[?25l")
      $this._cursorHidden = $true
    }
  }

  [void] Render([string[]]$lines) {
    if ($null -eq $lines) {
      $lines = [string[]]@()
    }

    [Monitor]::Enter($this._syncRoot)
    try {
      try {
        $this.Begin()

        if (!$this._supportsAnsi) {
          foreach ($line in $lines) {
            $this._writer.WriteLine($line)
          }
          return
        }

        $targetCount = [Math]::Max($this._lineCount, $lines.Length)
        if ($this._lineCount -gt 0) {
          $this._writer.Write(("`e[{0}F" -f $this._lineCount))
        }

        for ($index = 0; $index -lt $targetCount; $index++) {
          $this._writer.Write("`e[2K")
          if ($index -lt $lines.Length) {
            $this._writer.Write($lines[$index], [Style]::Plain)
          }
          # Always newline after each line so the cursor sits BELOW the progress
          # region. This ensures \e[{n}F on the next tick moves back exactly to
          # the start of the progress area and not one line further up into any
          # prior Write-Host output.
          $this._writer.WriteLine()
        }

        $this._lineCount = $targetCount
      } catch {
        Write-Warning "[LiveDisplayRegion] Render exception: $_"
        throw $_
      }
    } finally {
      [Monitor]::Exit($this._syncRoot)
    }
  }

  [void] Complete([string[]]$lines) {
    $this.Render($lines)
    $this.Dispose()
    # No extra WriteLine() here: Render() now always terminates every line
    # with a newline, so the cursor is already on a fresh line after Render().
  }

  [void] Dispose() {
    if ($this._supportsAnsi -and $this._cursorHidden) {
      $this._writer.Write("`e[?25h")
      $this._cursorHidden = $false
    }
  }
}

class ConsoleResolver {
  static [AnsiWriter] ResolveWriter([object]$consoleOrWriter) {
    if ($null -eq $consoleOrWriter) {
      throw [ArgumentNullException]::new('consoleOrWriter')
    }

    if ($consoleOrWriter -is [AnsiWriter]) {
      return [AnsiWriter]$consoleOrWriter
    }

    if ($consoleOrWriter -is [IAnsiConsole]) {
      $writer = $consoleOrWriter.GetWriter()
      if ($writer -is [AnsiWriter]) {
        return [AnsiWriter]$writer
      }
    }

    throw [ArgumentException]::new('Expected an AnsiWriter or IAnsiConsole-compatible object.', 'consoleOrWriter')
  }

  static [IAnsiConsole] ResolveConsole([object]$consoleOrWriter) {
    if ($null -eq $consoleOrWriter) {
      throw [ArgumentNullException]::new('consoleOrWriter')
    }

    if ($consoleOrWriter -is [IAnsiConsole]) {
      return [IAnsiConsole]$consoleOrWriter
    }

    throw [ArgumentException]::new('Expected an IAnsiConsole-compatible object.', 'consoleOrWriter')
  }
}

class ProgressColumn {
  [Progress]$Owner
  ProgressColumn() {}
  ProgressColumn([Progress]$owner) { $this.Owner = $owner }
  [bool] get_NoWrap() { return $true }
  [Nullable[int]] GetColumnWidth([RenderOptions]$options) { return $null }
  [IRenderable] Render([RenderOptions]$options, [ProgressTaskState]$task, [TimeSpan]$deltaTime) {
    throw [NotImplementedException]::new()
  }
}

class TaskDescriptionColumn : ProgressColumn {
  [Justify]$Alignment = [Justify]::Left
  TaskDescriptionColumn() : base() {}
  TaskDescriptionColumn([Progress]$owner) : base($owner) {}

  [IRenderable] Render([RenderOptions]$options, [ProgressTaskState]$task, [TimeSpan]$deltaTime) {
    $text = if ($null -ne $task.Description) { $task.Description } else { "" }
    $m = [Markup]::new($text)
    $m.Overflow = [Overflow]::Ellipsis
    $m.Justify = $this.Alignment
    return $m
  }
}

class PercentageColumn : ProgressColumn {
  [Style]$Style = [Style]::Parse("green")
  [Style]$CompletedStyle = [Style]::Parse("green")

  PercentageColumn() : base() {}
  PercentageColumn([Progress]$owner) : base($owner) {}

  [Nullable[int]] GetColumnWidth([RenderOptions]$options) { return 4 }

  [IRenderable] Render([RenderOptions]$options, [ProgressTaskState]$task, [TimeSpan]$deltaTime) {
    $pct = $task.Percent()
    $styleToUse = if ($task.get_IsFinished()) { $this.CompletedStyle } else { $this.Style }
    $text = '{0,3:N0}%' -f $pct
    return [Markup]::new($text, $styleToUse)
  }
}

class SpinnerColumn : ProgressColumn {
  [Spinner]$Spinner
  static [Spinner]$_defaultSpinnerCACHE
  static [Spinner]$_asciiSpinnerCACHE

  [Style]$Style = [Style]::Parse("yellow")
  [Style]$CompletedStyle = [Style]::Parse("green")
  [string]$CompletedText = '✓'
  [string]$PendingText = ' '

  SpinnerColumn() : base() {}
  SpinnerColumn([Progress]$owner) : base($owner) {}

  hidden [void] EnsureSpinner() {
    if ($null -eq $this.Spinner -or $null -eq $this.Spinner.Frames) {
      if ($null -eq [SpinnerColumn]::_defaultSpinnerCACHE) {
        $s = [Spinner]::new()
        $s.Name = 'Default'
        $s.Interval = [TimeSpan]::FromMilliseconds(100)
        $s.IsUnicode = $true
        $s.Frames = @('⣷', '⣯', '⣟', '⡿', '⢿', '⣻', '⣽', '⣾')
        [SpinnerColumn]::_defaultSpinnerCACHE = $s
      }
      $this.Spinner = [SpinnerColumn]::_defaultSpinnerCACHE
    }
    if ($null -eq [SpinnerColumn]::_asciiSpinnerCACHE) {
      $s = [Spinner]::new()
      $s.Name = 'Ascii'
      $s.Interval = [TimeSpan]::FromMilliseconds(100)
      $s.IsUnicode = $false
      $s.Frames = @('-', '\', '|', '/', '-', '\', '|', '/')
      [SpinnerColumn]::_asciiSpinnerCACHE = $s
    }
  }

  [Nullable[int]] GetColumnWidth([RenderOptions]$options) {
    $this.EnsureSpinner()
    $frames = if ($options.Unicode -or $this.Spinner.IsUnicode -eq $false) { $this.Spinner.Frames } else { [SpinnerColumn]::_asciiSpinnerCACHE.Frames }
    if ($null -eq $frames -or $frames.Length -eq 0) { return 1 }

    $maxWidth = 1
    foreach ($frame in $frames) {
      $len = [Cell]::GetCellLength($frame)
      if ($len -gt $maxWidth) { $maxWidth = $len }
    }
    return $maxWidth
  }

  hidden [double]$_accumulated = 0
  hidden [int]$_index = 0

  [IRenderable] Render([RenderOptions]$options, [ProgressTaskState]$task, [TimeSpan]$deltaTime) {
    if (!$task.get_IsStarted()) {
      return [Markup]::new($this.PendingText, [Style]::Plain)
    }
    if ($task.get_IsFinished()) {
      return [Markup]::new($this.CompletedText, $this.CompletedStyle)
    }

    $this.EnsureSpinner()

    $this._accumulated += $deltaTime.TotalMilliseconds
    if ($this._accumulated -ge $this.Spinner.Interval.TotalMilliseconds) {
      $this._accumulated -= $this.Spinner.Interval.TotalMilliseconds
      $this._index++
    }

    $spinnerList = if ($options.Unicode -or $this.Spinner.IsUnicode -eq $false) { $this.Spinner.Frames } else { [SpinnerColumn]::_asciiSpinnerCACHE.Frames }
    if ($null -eq $spinnerList -or $spinnerList.Length -eq 0) {
      return [Markup]::new(" ", $this.Style)
    }

    $frame = $spinnerList[$this._index % $spinnerList.Length]

    return [Markup]::new($frame, $this.Style)
  }
}

class ProgressBarColumn : ProgressColumn {
  [int]$Width = 40
  [Style]$CompletedStyle = [Style]::Parse("green")
  [Style]$FinishedStyle = [Style]::Parse("green")
  [Style]$RemainingStyle = [Style]::Parse("grey")
  ProgressBarColumn() : base() {}
  ProgressBarColumn([Progress]$owner) : base($owner) {}

  [Nullable[int]] GetColumnWidth([RenderOptions]$options) { return $this.Width }

  [IRenderable] Render([RenderOptions]$options, [ProgressTaskState]$task, [TimeSpan]$deltaTime) {
    $cfg = if ($options -is [ProgressConfig]) { [ProgressConfig]$options } else { $null }
    $renderable = [ProgressBarRenderable]::new($task, $this.Width, $this.CompletedStyle, $this.RemainingStyle, $this.FinishedStyle)
    $renderable.Options = $cfg
    return $renderable
  }
}

class ProgressBarRenderable : IRenderable {
  [ProgressTaskState]$Task
  [int]$Width
  [Style]$CompletedStyle
  [Style]$RemainingStyle
  [Style]$FinishedStyle
  # Stored by ProgressBarColumn.Render() so the ProgressConfig survives the Grid's
  # generic Render([RenderOptions],int) call contract.
  # Typed [object] to avoid PowerShell parse-time forward-reference errors.
  [object]$Options

  ProgressBarRenderable([ProgressTaskState]$task, [int]$width, [Style]$completedStyle, [Style]$remainingStyle, [Style]$finishedStyle) {
    $this.Task = $task
    $this.Width = $width
    $this.CompletedStyle = $completedStyle
    $this.RemainingStyle = $remainingStyle
    $this.FinishedStyle = $finishedStyle
  }

  # Override Measure() so the Grid column measurer sees the bar's actual width
  # instead of the full maxWidth (which would crowd out the percentage/spinner columns).
  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    $safeWidth = [Math]::Min($this.Width, $maxWidth)
    return [Measurement]::new($safeWidth, $safeWidth)
  }

  # Grid calls Render([RenderOptions], int) — we recover ProgressConfig from $this.Options.
  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    $cfg = if ($null -ne $this.Options) { $this.Options } elseif ($options -is [ProgressConfig]) { [ProgressConfig]$options } else { [ProgressConfig]::new() }
    $segs = [List[Segment]]::new()
    $safeWidth = [Math]::Min($this.Width, $maxWidth)
    $block = if ($cfg.ProgressBlock) { $cfg.ProgressBlock } else { '■' }

    if ($this.Task.IsIndeterminate) {
      $segs.Add([Segment]::new(('.' * $safeWidth), $this.RemainingStyle))
      return $segs.ToArray()
    }

    $pct = $this.Task.Percent()
    $filledCount = [Math]::Min($safeWidth, [int][Math]::Floor(($pct / 100) * $safeWidth))
    $emptyCount = [Math]::Max(0, $safeWidth - $filledCount)

    $actualCompStyle = if ($this.Task.get_IsFinished()) { $this.FinishedStyle } else { $this.CompletedStyle }

    if ($filledCount -gt 0) {
      $segs.Add([Segment]::new(($block * $filledCount), $actualCompStyle))
    }
    if ($emptyCount -gt 0) {
      $segs.Add([Segment]::new(('=' * $emptyCount), $this.RemainingStyle))
    }
    return $segs.ToArray()
  }
}

class ProgressRenderable : IRenderable {
  [Progress]$Owner
  [ProgressContext]$Context
  [TimeSpan]$DeltaTime

  ProgressRenderable([Progress]$owner, [ProgressContext]$context, [TimeSpan]$deltaTime) {
    $this.Owner = $owner
    $this.Context = $context
    $this.DeltaTime = $deltaTime
  }

  [Segment[]] Render([RenderOptions]$options, [int]$maxWidth) {
    try {
      # CRITICAL BUG FIX PRESERVATION (#2 Background Runspaces vs Renderers):
      # This Progress Engine renders explicitly via linear column formatting instead of using [Grid].
      # [Grid] leverages recursive TableMeasurers which can fail abruptly with background
      # [System.Threading.Timer] threads if [Segment]::Truncate aborts during a tight layout scale.
      $cfg = if ($options -is [ProgressConfig]) { [ProgressConfig]$options } else { [ProgressConfig]::new() }
      $tasks = $this.Context.GetTasks()
      $renderOpts = $cfg.ToRenderOptions()
      $result = [List[Segment]]::new()

      # Calculate exact max constraints across all tasks to align them as a simulated grid
      $colWidths = [int[]]::new($this.Owner.Columns.Count)
      foreach ($task in $tasks) {
        for ($i = 0; $i -lt $this.Owner.Columns.Count; $i++) {
          $col = $this.Owner.Columns[$i]
          $w = $col.GetColumnWidth($cfg)
          if ($null -ne $w) {
            $colWidths[$i] = [Math]::Max($colWidths[$i], [int]$w)
          } else {
            # Pass zero DeltaTime during measurement phase to prevent double-ticking animations
            $r = $col.Render($cfg, $task, [TimeSpan]::Zero)
            if ($null -ne $r) {
              # CRITICAL BUG FIX PRESERVATION (#3 PowerShell Polymorphism):
              # We wrap $r inside an array @($r)[0] to guarantee we evaluate the concrete instance.
              # In certain PS versions passing interfaces natively over virtual tables fails dispatching to inherited classes.
              $m = @($r)[0].Measure($renderOpts, $maxWidth)
              $colWidths[$i] = [Math]::Max($colWidths[$i], [int]$m.Max)
            }
          }
        }
      }

      # Manual sequence emission
      foreach ($task in $tasks) {
        $lineSegments = [List[Segment]]::new()
        for ($i = 0; $i -lt $this.Owner.Columns.Count; $i++) {
          $col = $this.Owner.Columns[$i]
          $renderable = $col.Render($cfg, $task, $this.DeltaTime)
          if ($null -eq $renderable) { continue }

          $colW = $colWidths[$i]
          $rendered = @($renderable)[0].Render($renderOpts, $colW)
          # Avoid AddRange unwrapping anomalies
          foreach ($s in $rendered) { $lineSegments.Add($s) }

          $actualLen = [Segment]::CellCount($rendered)
          if ($actualLen -lt $colW) {
            $pad = " " * ($colW - $actualLen)
            $lineSegments.Add([Segment]::new($pad, [Style]::Plain))
          }

          if ($i -lt $this.Owner.Columns.Count - 1) {
            $lineSegments.Add([Segment]::new(" ", [Style]::Plain))
          }
        }

        if ([Segment]::CellCount($lineSegments) -gt $maxWidth) {
          foreach ($s in [Segment]::Truncate($lineSegments, $maxWidth)) { $result.Add($s) }
        } else {
          foreach ($s in $lineSegments) { $result.Add($s) }
        }
        $result.Add([Segment]::LineBreak)
      }

      return $result.ToArray()
    } catch {
      Write-Warning "[ProgressRenderable] Render exception: $_"
      return @([Segment]::new(" [Render Error] ", [Style]::Plain))
    }
  }
}

class ProgressLiveSession {
  [Progress]$Owner
  [ProgressContext]$Context
  [LiveDisplayRegion]$Display
  [int]$Frame = 0
  [DateTime]$LastUpdate = [DateTime]::UtcNow
  [string[]]$LastLines = [string[]]@()

  ProgressLiveSession([Progress]$Owner) {
    $this.Owner = $Owner
    $this.PsObject.Properties.Add([PSscriptProperty]::new("settings", { return $this.Owner.Config }, { param($settings) $this.Owner.Config = ($settings -is [ProgressConfig]) ? $settings : [ProgressConfig]::new($settings) }))
  }
  ProgressLiveSession([Progress]$Owner, [ProgressContext]$context, [LiveDisplayRegion]$display) {
    $this.Owner = $Owner
    $this.Context = $context
    $this.Display = $display
    $this.PsObject.Properties.Add([PSscriptProperty]::new("settings", { return $this.Owner.Config }, { param($settings) $this.Owner.Config = ($settings -is [ProgressConfig]) ? $settings : [ProgressConfig]::new($settings) }))
  }

  [void] Tick([object]$state) {
    try {
      $now = [DateTime]::UtcNow
      $delta = $now - $this.LastUpdate
      $this.LastUpdate = $now

      $renderable = [ProgressRenderable]::new($this.Owner, $this.Context, $delta)

      $options = [ProgressConfig]::Create($this.Owner.Writer, $this.Owner.Writer.Capabilities)
      [Segment[]]$segs = $renderable.Render($options, $this.Owner.GetRenderWidth())
      $lines = [Segment]::SplitLines($segs, $this.Owner.GetRenderWidth())

      $renderedLines = [List[string]]::new()
      foreach ($line in $lines) {
        $sb = [Text.StringBuilder]::new()
        foreach ($seg in $line.Segments) {
          $hasColor = $this.Owner.Writer.Capabilities.Ansi -and $null -ne $seg.Style -and $seg.Style -ne [Style]::Plain
          if ($hasColor) { [void]$sb.Append("`e[" + [AnsiCodeBuilder]::GetAnsi($seg.Style, $this.Owner.Writer.Capabilities.ColorSystem) + "m") }
          [void]$sb.Append($seg.Text)
          if ($hasColor) { [void]$sb.Append("`e[0m") }
        }
        $renderedLines.Add($sb.ToString())
      }

      $this.LastLines = $renderedLines.ToArray()
      $this.Frame++
      $this.Display.Render($this.LastLines)
    } catch {
      Write-Warning "[ProgressLiveSession] Tick exception: $_"
    }
  }
}

class ProgressRefreshThread : IDisposable {
  hidden [Timer]$_timer

  ProgressRefreshThread([TimerCallback]$callback, [int]$refreshRateMs) {
    $period = [Math]::Max(30, $refreshRateMs)
    $this._timer = [Timer]::new($callback, $null, 0, $period)
  }

  [void] Dispose() {
    if ($null -ne $this._timer) {
      $this._timer.Dispose()
      $this._timer = $null
    }
  }
}

class Progress {
  [AnsiWriter]$Writer
  [int]$RefreshRateMs = 100
  [List[ProgressColumn]]$Columns
  [ProgressLiveSession]$Session
  [ProgressConfig]$Config = @{}

  Progress([AnsiWriter]$writer) {
    $this.Initialize($writer)
  }

  Progress([IAnsiConsole]$console) {
    $this.Initialize([ConsoleResolver]::ResolveWriter($console))
  }

  Progress([object]$consoleOrWriter) {
    $this.Initialize([ConsoleResolver]::ResolveWriter($consoleOrWriter))
  }

  [void] Initialize([AnsiWriter]$Writer) {
    $this.Writer = $Writer
    $this.InitializeColumns()
  }

  hidden [void] InitializeColumns() {
    $this.Columns = [List[ProgressColumn]]::new()
    $this.Columns.Add([TaskDescriptionColumn]::new($this))
    $this.Columns.Add([ProgressBarColumn]::new($this))
    $this.Columns.Add([PercentageColumn]::new($this))
    $this.Columns.Add([SpinnerColumn]::new($this))
  }
  [void] Columns([ProgressColumn[]]$columns) {
    $this.Columns.Clear()
    $this.Columns.AddRange($columns)
  }

  [void] Start([Action[ProgressContext]]$action) {
    $context = [ProgressContext]::new()
    $this.Start($context, $action)
  }

  [void] Start([ProgressContext]$context, [Action[ProgressContext]]$action) {
    $display = [LiveDisplayRegion]::new($this.Writer)
    $this.session = [ProgressLiveSession]::new([Progress]$this, $context, $display)

    # Render synchronously on task updates to avoid PowerShell runspace deadlocks.
    # NOTE: $this is NOT available inside a [Action]/scriptblock closure in PowerShell
    # classes — capture the session reference in a local variable first.
    $liveSession = $this.session
    $context.OnUpdate = [Action] { $liveSession.Tick($null) }

    try {
      $this.session.Tick($null) # Initial render
      # Execute the user's action synchronously in the main runspace.
      $action.Invoke($context)
    } finally {
      $this.session.Tick($null) # final render (100 %)
      $display.Complete($this.session.LastLines)
    }
  }
  hidden [int] GetRenderWidth() {
    try {
      return [Math]::Max(40, [Console]::WindowWidth - 1)
    } catch {
      return 80
    }
  }
  static [Task[]] RunConcurrently([ScriptBlock[]]$workItems) {
    $tasks = [List[Task]]::new()
    foreach ($workItem in $workItems) {
      $tasks.Add([Task]::Run([Action] { & $workItem }))
    }
    return $tasks.ToArray()
  }

  static [void] WaitAll([Task[]]$tasks) {
    if ($null -eq $tasks -or $tasks.Length -eq 0) { return }
    [Task]::WaitAll($tasks)
  }
}
