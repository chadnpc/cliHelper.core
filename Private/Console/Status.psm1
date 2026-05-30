using namespace System
using namespace System.Threading

using module .\Ansi.psm1
using module .\Colors.psm1
using module .\Rendering.psm1
using module .\Progress.psm1
using module .\Spinners.psm1

class StatusContext {
  hidden [object]$_syncRoot
  [string]$Message
  [bool]$IsCompleted
  [bool]$IsFailed

  StatusContext([string]$message) {
    $this._syncRoot = [object]::new()
    $this.Message = $message
    $this.IsCompleted = $false
    $this.IsFailed = $false
  }

  [void] Update([string]$message) {
    [Monitor]::Enter($this._syncRoot)
    try {
      $this.Message = $message
    } finally {
      [Monitor]::Exit($this._syncRoot)
    }
  }

  [void] Complete() {
    [Monitor]::Enter($this._syncRoot)
    try {
      $this.IsCompleted = $true
    } finally {
      [Monitor]::Exit($this._syncRoot)
    }
  }

  [void] Fail() {
    [Monitor]::Enter($this._syncRoot)
    try {
      $this.IsFailed = $true
    } finally {
      [Monitor]::Exit($this._syncRoot)
    }
  }

  [string] SnapshotMessage() {
    [Monitor]::Enter($this._syncRoot)
    try {
      return $this.Message
    } finally {
      [Monitor]::Exit($this._syncRoot)
    }
  }
}

class StatusLiveSession {
  [Status]$Owner
  [StatusContext]$Context
  [LiveDisplayRegion]$Display
  [int]$Frame

  StatusLiveSession([Status]$owner, [StatusContext]$context, [LiveDisplayRegion]$display) {
    $this.Owner = $owner
    $this.Context = $context
    $this.Display = $display
    $this.Frame = 0
  }

  [void] Tick([object]$state) {
    $line = $this.Owner.RenderLine($this.Context.SnapshotMessage(), $this.Frame, $false, $false)
    $this.Frame++
    $this.Display.Render([string[]]@($line))
  }
}

class Status {
  [AnsiWriter]$Writer
  [Spinner]$Spinner
  [Style]$SpinnerStyle
  [int]$RefreshRateMs = 120

  Status([AnsiWriter]$writer) {
    $this.Writer = $writer
    $this.Spinner = [Spinner]""
    $this.SpinnerStyle = [Color]::Yellow
  }

  [void] Start([string]$message, [Action[StatusContext]]$action) {
    $context = [StatusContext]::new($message)
    $display = [LiveDisplayRegion]::new($this.Writer)
    $session = [StatusLiveSession]::new($this, $context, $display)
    $refresh = if ($null -ne $this.Spinner -and $this.Spinner.Interval.TotalMilliseconds -gt 0) { $this.Spinner.Interval.TotalMilliseconds } else { $this.RefreshRateMs }
    $thread = [ProgressRefreshThread]::new(([TimerCallback] $session.Tick), $refresh)
    $failed = $false

    try {
      $action.Invoke($context)
      $context.Complete()
      $session.Tick($null)
    } catch {
      $failed = $true
      $context.Fail()
      throw
    } finally {
      $thread.Dispose()
      $finalLine = $this.RenderLine($context.SnapshotMessage(), $session.Frame, $true, $failed)
      $display.Complete([string[]]@($finalLine))
    }
  }

  hidden [string] RenderLine([string]$message, [int]$frame, [bool]$isFinal, [bool]$isFailed) {
    $safeMessage = if ([string]::IsNullOrWhiteSpace($message)) { 'Working' } else { $message }
    if ($isFinal) {
      $marker = if ($isFailed) { 'x' } else { '+' }
      return '{0} {1}' -f $marker, $safeMessage
    }

    $spinnerList = if ($this.Writer.Capabilities.Unicode -or $this.Spinner.IsUnicode -eq $false) { $this.Spinner.Frames } else { ([spinner]"Ascii").Frames }
    $spinnerFrame = $spinnerList[$frame % $spinnerList.Length]

    if ($this.SpinnerStyle -and $this.Writer.Capabilities.Ansi) {
      $spinnerFrame = "`e[" + [AnsiCodeBuilder]::GetAnsi($this.SpinnerStyle, $this.Writer.Capabilities.ColorSystem) + "m" + $spinnerFrame + "`e[0m"
    }

    return '{0} {1}' -f $spinnerFrame, $safeMessage
  }
}
