using namespace System
using namespace System.Threading
using namespace System.Collections.Generic

using module .\Ansi.psm1
using module .\Enums.psm1
using module .\Rendering.psm1
using module .\Progress.psm1

class LiveDisplayContext {
  [LiveDisplay]$Owner

  LiveDisplayContext([LiveDisplay]$owner) {
    $this.Owner = $owner
  }

  [void] UpdateTarget([IRenderable]$target) {
    $this.Owner.Target = $target
  }

  [void] Refresh() {
  }
}

class LiveDisplaySession {
  [LiveDisplay]$Owner
  [LiveDisplayContext]$Context
  [LiveDisplayRegion]$Display
  [string[]]$LastLines

  LiveDisplaySession([LiveDisplay]$owner, [LiveDisplayContext]$context, [LiveDisplayRegion]$display) {
    $this.Owner = $owner
    $this.Context = $context
    $this.Display = $display
    $this.LastLines = [string[]]@()
  }

  [void] Tick([object]$state) {
    if ($null -eq $this.Owner.Target) { return }

    $options = [RenderOptions]::Create($this.Owner.Writer, $this.Owner.Writer.Capabilities)
    $segs = $this.Owner.Target.Render($options, $this.Owner.GetRenderWidth())
    $lines = [Segment]::SplitLines($segs, $this.Owner.GetRenderWidth())

    $renderedLines = [List[string]]::new()
    foreach ($line in $lines) {
      $sb = [Text.StringBuilder]::new()
      foreach ($seg in $line.Segments) {
        $hasColor = $this.Owner.Writer.Capabilities.Ansi -and $null -ne $seg.Style -and $seg.Style -ne [Style]::Plain
        if ($hasColor) {
          [void]$sb.Append("`e[" + [AnsiCodeBuilder]::GetAnsi($seg.Style, $this.Owner.Writer.Capabilities.ColorSystem) + "m")
        }
        [void]$sb.Append($seg.Text)
        if ($hasColor) {
          [void]$sb.Append("`e[0m")
        }
      }
      $renderedLines.Add($sb.ToString())
    }

    $this.LastLines = $renderedLines.ToArray()
    $this.Display.Render($this.LastLines)
  }
}

class LiveDisplay {
  [AnsiWriter]$Writer
  [IRenderable]$Target
  [int]$RefreshRateMs = 100

  LiveDisplay([AnsiWriter]$writer, [IRenderable]$target) {
    $this.Writer = $writer
    $this.Target = $target
  }

  [void] Start([Action[LiveDisplayContext]]$action) {
    $context = [LiveDisplayContext]::new($this)
    $display = [LiveDisplayRegion]::new($this.Writer)
    $session = [LiveDisplaySession]::new($this, $context, $display)
    $thread = [ProgressRefreshThread]::new(([TimerCallback] $session.Tick), $this.RefreshRateMs)

    try {
      $action.Invoke($context)
      $session.Tick($null)
    } finally {
      $thread.Dispose()
      $session.Tick($null)
      $display.Complete($session.LastLines)
    }
  }

  hidden [int] GetRenderWidth() {
    try {
      return [Math]::Max(40, [Console]::WindowWidth)
    } catch {
      return 80
    }
  }
}
