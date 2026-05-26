using namespace System
using namespace System.IO
using namespace System.Threading


using module .\Enums.psm1
using module .\Internal.psm1
using module .\Colors.psm1
using module .\Rendering.psm1
using module .\Ansi.psm1
using module .\Renderer.psm1
using module .\Boxes.psm1
using module .\Widgets.psm1

class AnsiConsoleFacade : IAnsiConsole {
  hidden [object]$_renderLock
  hidden [AnsiWriter]$_writer
  hidden [AnsiMarkup]$_markup

  AnsiConsoleFacade([AnsiWriter]$writer) {
    $this._writer = $writer
    $this._markup = [AnsiMarkup]::new($writer)

    $prof = [Profile]::new()
    $prof.Capabilities = $writer.Capabilities
    $prof.Out = [AnsiConsoleOutput]::new($writer.GetOutput())
    $this.Profile = $prof

    $this.Cursor = [NoopCursor]::new()
    $this.Input = [IAnsiConsoleInput]::new()
    $this.ExclusivityMode = [NoopExclusivityMode]::new()
    $this._renderLock = [object]::new()
  }
  [void] Write([string]$string) {
    $this.Write($string, $false)
  }
  [void] Write([string]$string, [bool]$animate) {
    $this.toggle_animation($animate)
    $this.Write([Text]$string)
  }
  [void] Write([IRenderable]$renderable) {
    if ($null -eq $renderable) { return }
    [Monitor]::Enter($this._renderLock)
    try {
      [ConsoleRenderer]::Render($this, $renderable)
    } finally {
      [Monitor]::Exit($this._renderLock)
    }
  }
  [void] WriteLine([string]$string) {
    $this.WriteLine($string, $false)
  }
  [void] WriteLine([string]$string, [bool]$animate) {
    $this.toggle_animation($animate)
    $this.WriteObject($string)
    $this._writer.WriteLine()
  }
  [void] WriteObject([object]$value) {
    if ($value -is [IRenderable]) {
      $this.Write([IRenderable]$value)
      return
    }

    if ($value -is [string] -and $value -match '\[[^\]]+\]') {
      $this.Write([Markup]::new([string]$value))
      return
    }

    $text = if ($null -eq $value) { [string]::Empty } else { [string]$value }
    $this.Write([Text]::new($text, [Style]::Plain))
  }

  [void] WriteAnsi([Action[AnsiWriter]]$action) {
    if ($null -eq $action) {
      return
    }

    [Monitor]::Enter($this._renderLock)
    try {
      $action.Invoke($this._writer)
    } finally {
      [Monitor]::Exit($this._renderLock)
    }
  }

  [void] Markup([string]$markup) {
    $this.Markup($markup, [Style]::Plain)
  }

  [void] Markup([string]$markup, [Style]$style) {
    [Monitor]::Enter($this._renderLock)
    try {
      $this._markup.Write($markup, $style)
    } finally {
      [Monitor]::Exit($this._renderLock)
    }
  }

  [void] MarkupLine([string]$markup) {
    $this.Markup($markup)
    $this._writer.WriteLine()
  }
  [void] Clear() {
    $this.Clear($true)
  }

  [void] Clear([bool]$CursorHome) {
    [Monitor]::Enter($this._renderLock)
    try {
      if ($this._writer.Capabilities.Ansi) {
        $this._writer.Write("`e[2J")
        if ($CursorHome) {
          $this._writer.Write("`e[H")
        }
      } else {
        [Console]::Clear()
      }
    } finally {
      [Monitor]::Exit($this._renderLock)
    }
  }
  [AnsiWriter] GetWriter() {
    return $this._writer
  }
  hidden [void] toggle_animation([bool]$condition) {
    # .NOTES
    # typing animation only works when we use $host.UI.Write(..) not [console]::write(..)
    $this._writer._output.UseTypingEffect = $condition
    $this._writer._output.WriteRaw = !$condition
  }
}

class AnsiConsole {
  static [IAnsiConsole] $Console

  static AnsiConsole() {
    [AnsiConsole]::Initialize()
  }

  static [void] Markup([string]$markup) {
    ([AnsiConsoleFacade][AnsiConsole]::Console).Markup($markup)
  }

  static [void] MarkupLine([string]$markup) {
    ([AnsiConsoleFacade][AnsiConsole]::Console).MarkupLine($markup)
  }

  static [void] Clear() {
    [AnsiConsole]::Console.Clear()
  }

  static [void] Write([object]$value) {
    ([AnsiConsoleFacade][AnsiConsole]::Console).WriteObject($value)
  }

  static [void] WriteLine([string]$text) {
    ([AnsiConsoleFacade][AnsiConsole]::Console).WriteLine($text)
  }

  static [void] Initialize() {
    [AnsiConsole]::Console = [AnsiConsoleFactory]::Create([AnsiConsoleSettings]::new())
  }
}

class AnsiConsoleFactory {
  static [IAnsiConsole] Create([AnsiConsoleSettings]$settings) {
    if ($null -eq $settings) {
      $settings = [AnsiConsoleSettings]::new()
    }

    if ($null -eq $settings.Out) {
      $settings.Out = [AnsiConsoleOutput]::new([ConsoleWriter]::new())
    }

    $writer = [AnsiWriter]::new($settings.Out.Writer)
    $writer.Capabilities = [AnsiConsoleFactory]::ResolveCapabilities($settings)
    return [AnsiConsoleFacade]::new($writer)
  }

  static hidden [AnsiCapabilities] ResolveCapabilities([AnsiConsoleSettings]$settings) {
    $capabilities = [AnsiCapabilities]::new()
    $capabilities.Ansi = [AnsiConsoleFactory]::ResolveAnsiSupport($settings.Ansi)
    $capabilities.ColorSystem = [AnsiConsoleFactory]::ResolveColorSystem($settings.ColorSystem)
    $capabilities.Links = $capabilities.Ansi
    $capabilities.AlternateBuffer = $capabilities.Ansi
    return $capabilities
  }

  static hidden [bool] ResolveAnsiSupport([AnsiSupport]$support) {
    switch ($support) {
      ([AnsiSupport]::Yes) { return $true }
      ([AnsiSupport]::No) { return $false }
      default {
        $term = [Environment]::GetEnvironmentVariable('TERM')
        return -not [string]::IsNullOrWhiteSpace($term) -or -not [Console]::IsOutputRedirected
      }
    }

    return $false
  }

  static hidden [ColorSystem] ResolveColorSystem([ColorSystemSupport]$support) {
    switch ($support) {
      ([ColorSystemSupport]::NoColors) { return [ColorSystem]::NoColors }
      ([ColorSystemSupport]::Legacy) { return [ColorSystem]::Legacy }
      ([ColorSystemSupport]::Standard) { return [ColorSystem]::Standard }
      ([ColorSystemSupport]::EightBit) { return [ColorSystem]::EightBit }
      ([ColorSystemSupport]::TrueColor) { return [ColorSystem]::TrueColor }
      default {
        $colorterm = [Environment]::GetEnvironmentVariable('COLORTERM')
        if ($colorterm -match 'truecolor|24bit') {
          return [ColorSystem]::TrueColor
        }

        return [Console]::IsOutputRedirected ? [ColorSystem]::NoColors : [ColorSystem]::TrueColor
      }
    }

    return [ColorSystem]::NoColors
  }
}

class AnsiConsoleOutput {
  [ConsoleWriter]$Writer
  AnsiConsoleOutput([ConsoleWriter]$writer) {
    $this.Writer = $writer
  }
}

class AnsiConsoleSettings {
  [AnsiSupport]$Ansi = [AnsiSupport]::Detect
  [ColorSystemSupport]$ColorSystem = [ColorSystemSupport]::Detect
  [AnsiConsoleOutput]$Out = [AnsiConsoleOutput]::new([ConsoleWriter]::new())
}

class Profile {
  [AnsiCapabilities]$Capabilities
  [AnsiConsoleOutput]$Out
  [int]$Width
  [int]$Height

  Profile() {
    $this.Capabilities = [AnsiCapabilities]::new()
    $this.Out = [AnsiConsoleOutput]::new([ConsoleWriter]::new())
    $this.Width = 0
    $this.Height = 0
  }

  [int] GetWidth() {
    if ($this.Width -gt 0) {
      return $this.Width
    }

    try {
      return [Math]::Max(1, [Console]::WindowWidth)
    } catch {
      return 80
    }
  }

  [int] GetHeight() {
    if ($this.Height -gt 0) {
      return $this.Height
    }

    try {
      return [Math]::Max(1, [Console]::WindowHeight)
    } catch {
      return 25
    }
  }

  [RenderOptions] CreateRenderOptions() {
    $options = [RenderOptions]::new()
    $options.ColorSystem = $this.Capabilities.ColorSystem
    $options.Ansi = $this.Capabilities.Ansi
    return $options
  }
}

