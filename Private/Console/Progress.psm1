using namespace System
using namespace System.Collections.Generic
using namespace System.Threading
using namespace System.Threading.Tasks

using module ..\Models.psm1
using module .\Colors.psm1
using module .\Rendering.psm1
using module .\Ansi.psm1
using module .\Spinners.psm1
using module .\Layout.psm1
using module .\Widgets.psm1
using module .\Enums.psm1

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

class ProgressLiveSessionSettings : PsRecord {
  $ShowProgress = { return (Get-Variable 'VerbosePreference' -ValueOnly) -eq 'Continue' }
  $ProgressBarColor = "LightSeaGreen"
  $ProgressMsgColor = "LightGoldenrodYellow"
  $ProgressBlock = '■'
  ProgressLiveSessionSettings() : base() {}
  ProgressLiveSessionSettings($hashtable): base($hashtable) {
  }
  ProgressLiveSessionSettings([hashtable[]]$array): base($array) {
  }
}

class ProgressTaskSettings {
  [double]$MaxValue = 100
  [bool]$AutoStart = $true
  [bool]$IsIndeterminate = $false
}

class ProgressContext {
  hidden [List[ProgressTaskState]]$_tasks
  hidden [int]$_nextId
  hidden [object]$_syncRoot
  [Action]$OnUpdate

  ProgressContext() {
    $this._tasks = [List[ProgressTaskState]]::new()
    $this._nextId = 1
    $this._syncRoot = [object]::new()
  }

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
  [bool] get_NoWrap() { return $true }
  [Nullable[int]] GetColumnWidth([RenderOptions]$options) { return $null }
  [IRenderable] Render([RenderOptions]$options, [ProgressTaskState]$task, [TimeSpan]$deltaTime) { throw [NotImplementedException]::new() }
}

class TaskDescriptionColumn : ProgressColumn {
  [Justify]$Alignment = [Justify]::Left

  [IRenderable] Render([RenderOptions]$options, [ProgressTaskState]$task, [TimeSpan]$deltaTime) {
    $text = if ($null -ne $task.Description) { $task.Description } else { "" }
    $m = [Markup]::new($text)
    $m.Overflow = [Overflow]::Ellipsis
    $m.Justify = $this.Alignment
    return $m
  }
}

class PercentageColumn : ProgressColumn {
  [Style]$Style = [Color]::Green
  [Style]$CompletedStyle = [Color]::Green

  [IRenderable] Render([RenderOptions]$options, [ProgressTaskState]$task, [TimeSpan]$deltaTime) {
    $pct = $task.Percent()
    $styleToUse = if ($task.IsFinished) { $this.CompletedStyle } else { $this.Style }
    $text = '{0,3:N0}%' -f $pct
    return [Markup]::new($text, $styleToUse)
  }
}

class SpinnerColumn : ProgressColumn {
  [Spinner]$Spinner = [SpinnerKnown]::Default
  [Style]$Style = [Color]::Yellow
  [Style]$CompletedStyle = [Style]::Plain
  [string]$CompletedText = ''
  [string]$PendingText = ' '

  hidden [double]$_accumulated = 0
  hidden [int]$_index = 0

  [IRenderable] Render([RenderOptions]$options, [ProgressTaskState]$task, [TimeSpan]$deltaTime) {
    if (!$task.IsStarted) {
      return [Markup]::new($this.PendingText, [Style]::Plain)
    }
    if ($task.IsFinished) {
      return [Markup]::new($this.CompletedText, $this.CompletedStyle)
    }

    $this._accumulated += $deltaTime.TotalMilliseconds
    if ($this._accumulated -ge $this.Spinner.Interval.TotalMilliseconds) {
      $this._accumulated -= $this.Spinner.Interval.TotalMilliseconds
      $this._index++
    }

    $spinnerList = if ($options.Unicode -or $this.Spinner.IsUnicode -eq $false) { $this.Spinner.Frames } else { [SpinnerKnown]::Ascii.Frames }
    $frame = $spinnerList[$this._index % $spinnerList.Length]

    return [Markup]::new($frame, $this.Style)
  }
}

class ProgressBarColumn : ProgressColumn {
  [int]$Width = 40
  [Style]$CompletedStyle = [Color]::Green
  [Style]$FinishedStyle = [Color]::Green
  [Style]$RemainingStyle = [Color]::Grey

  [IRenderable] Render([RenderOptions]$options, [ProgressTaskState]$task, [TimeSpan]$deltaTime) {
    return [ProgressBarRenderable]::new($task, $this.Width, $this.CompletedStyle, $this.RemainingStyle, $this.FinishedStyle)
  }
}

class ProgressBarRenderable : IRenderable {
  [ProgressTaskState]$Task
  [int]$Width
  [Style]$CompletedStyle
  [Style]$RemainingStyle
  [Style]$FinishedStyle

  ProgressBarRenderable([ProgressTaskState]$task, [int]$width, [Style]$completedStyle, [Style]$remainingStyle, [Style]$finishedStyle) {
    $this.Task = $task
    $this.Width = $width
    $this.CompletedStyle = $completedStyle
    $this.RemainingStyle = $remainingStyle
    $this.FinishedStyle = $finishedStyle
  }

  [IEnumerable[Segment]] Render([RenderOptions]$options, [int]$maxWidth) {
    $segs = [List[Segment]]::new()
    $safeWidth = [Math]::Min($this.Width, $maxWidth)

    if ($this.Task.IsIndeterminate) {
      $segs.Add([Segment]::new(('.' * $safeWidth), $this.RemainingStyle))
      return $segs.ToArray()
    }

    $pct = $this.Task.Percent()
    $filledCount = [Math]::Min($safeWidth, [int][Math]::Floor(($pct / 100) * $safeWidth))
    $emptyCount = [Math]::Max(0, $safeWidth - $filledCount)

    $actualCompStyle = if ($this.Task.IsFinished) { $this.FinishedStyle } else { $this.CompletedStyle }

    if ($filledCount -gt 0) {
      $segs.Add([Segment]::new(('=' * $filledCount), $actualCompStyle))
    }
    if ($emptyCount -gt 0) {
      $segs.Add([Segment]::new(('-' * $emptyCount), $this.RemainingStyle))
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

  [IEnumerable[Segment]] Render([RenderOptions]$options, [int]$maxWidth) {
    $tasks = $this.Context.GetTasks()
    $grid = [Grid]::new()

    for ($i = 0; $i -lt $this.Owner.Columns.Count; $i++) {
      $colWidth = $this.Owner.Columns[$i].GetColumnWidth($options)
      $col = [GridColumn]::new().PadRight(1)
      if ($null -ne $colWidth) { $col.Width = $colWidth }
      if ($this.Owner.Columns[$i].NoWrap) { [void]$col.NoWrap() }
      if ($i -eq $this.Owner.Columns.Count - 1) { [void]$col.PadRight(0) }
      [void]$grid.AddColumn($col)
    }

    foreach ($task in $tasks) {
      $rowRenderables = [List[IRenderable]]::new()
      foreach ($col in $this.Owner.Columns) {
        $rowRenderables.Add($col.Render($options, $task, $this.DeltaTime))
      }
      [void]$grid.AddRow($rowRenderables.ToArray())
    }

    return $grid.Render($options, $maxWidth)
  }
}

class ProgressLiveSession {
  [Progress]$Owner
  [ProgressContext]$Context
  [LiveDisplayRegion]$Display
  [int]$Frame
  [DateTime]$LastUpdate
  [string[]]$LastLines
  [ProgressLiveSessionSettings]$settings

  ProgressLiveSession([Progress]$owner, [ProgressContext]$context, [LiveDisplayRegion]$display) {
    $this.Owner = $owner
    $this.Context = $context
    $this.Display = $display
    $this.Frame = 0
    $this.LastUpdate = [DateTime]::UtcNow
    $this.LastLines = [string[]]@()
  }

  [void] Tick([object]$state) {
    $now = [DateTime]::UtcNow
    $delta = $now - $this.LastUpdate
    $this.LastUpdate = $now

    $renderable = [ProgressRenderable]::new($this.Owner, $this.Context, $delta)

    $options = [RenderOptions]::Create($this.Owner.Writer, $this.Owner.Writer.Capabilities)
    $segs = $renderable.Render($options, $this.Owner.GetRenderWidth())
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
  [ProgressLiveSession]$session

  Progress([AnsiWriter]$writer) {
    $this.Writer = $writer
    $this.InitializeColumns()
  }

  Progress([IAnsiConsole]$console) {
    $this.Writer = [ConsoleResolver]::ResolveWriter($console)
    $this.InitializeColumns()
  }

  Progress([object]$consoleOrWriter) {
    $this.Writer = [ConsoleResolver]::ResolveWriter($consoleOrWriter)
    $this.InitializeColumns()
  }

  hidden [void] InitializeColumns() {
    $this.Columns = [List[ProgressColumn]]::new()
    $this.Columns.Add([TaskDescriptionColumn]::new())
    $this.Columns.Add([ProgressBarColumn]::new())
    $this.Columns.Add([PercentageColumn]::new())
    $this.Columns.Add([SpinnerColumn]::new())
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
    $this.session = [ProgressLiveSession]::new($this, $context, $display)

    # Render synchronously on task updates to avoid PowerShell runspace deadlocks.
    $context.OnUpdate = [Action] { $this.session.Tick($null) }

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
