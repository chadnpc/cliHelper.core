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

class ConsoleCoordinate {
  [int]$X
  [int]$Y
  ConsoleCoordinate([int]$X, [int]$Y) { $this.X = $X; $this.Y = $Y }
}

class ConsoleReader : System.IO.TextReader {
  ConsoleReader() : base() { }
  [int] Read() {
    $key = [Console]::ReadKey($true)
    return [int][char]$key.KeyChar
  }
  [int] Read([char[]]$buffer, [int]$index, [int]$count) {
    if ($null -eq $buffer) {
      throw [ArgumentNullException]::new("buffer")
    }
    if ($index -lt 0 -or $count -lt 0) {
      throw [ArgumentOutOfRangeException]::new("Index and count must be non-negative")
    }
    if ($buffer.Length - $index -lt $count) {
      throw [ArgumentException]::new("Buffer too small")
    }

    $charsRead = 0
    while ($charsRead -lt $count -and [Console]::KeyAvailable) {
      $key = [Console]::ReadKey($true)
      $buffer[$index + $charsRead] = $key.KeyChar
      $charsRead++
    }
    return $charsRead
  }
  [string] ReadLine() {
    return [Console]::ReadLine()
  }
}


class ConsoleWriter : System.IO.TextWriter {
  static hidden [string] $LeadPreffix
  static hidden [bool] $UseTypingEffect = $true
  static hidden [bool] $UseLeadPreffix = ![string]::IsNullOrWhiteSpace([ConsoleWriter]::LeadPreffix)
  static hidden [string[]] $Colors = [ConsoleWriter]::get_ColorNames()
  static hidden [ValidateNotNull()][scriptblock]$ValidateScript = { param($arg) if ([String]::IsNullOrEmpty($arg)) { throw [ArgumentNullException]::new('text', 'Cannot be Null Or Empty') } }

  static [string] write([string]$text) {
    return [ConsoleWriter]::Write($text, 20, 1200)
  }
  static [string] Write([string]$text, [bool]$AddPreffix) {
    return [ConsoleWriter]::Write($text, 20, 1200, $AddPreffix)
  }
  static [string] Write([string]$text, [int]$Speed, [int]$Duration) {
    return [ConsoleWriter]::Write($text, 20, 1200, [ConsoleWriter]::UseLeadPreffix)
  }
  static [string] write([string]$text, [ConsoleColor]$color) {
    return [ConsoleWriter]::Write($text, $color, [ConsoleWriter]::UseTypingEffect)
  }
  static [string] write([string]$text, [ConsoleColor]$color, [bool]$Animate) {
    return [ConsoleWriter]::Write($text, [ConsoleWriter]::LeadPreffix, 20, 1200, $color, $Animate, [ConsoleWriter]::LeadPreffix)
  }
  static [string] write([string]$text, [int]$Speed, [int]$Duration, [bool]$AddPreffix) {
    return [ConsoleWriter]::Write($text, [ConsoleWriter]::LeadPreffix, $Speed, $Duration, [ConsoleColor]::White, [ConsoleWriter]::UseTypingEffect, $AddPreffix)
  }
  static [string] write([string]$text, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix) {
    return [ConsoleWriter]::Write($text, [ConsoleWriter]::LeadPreffix, 20, 1200, $color, $Animate, $AddPreffix)
  }
  static [string] write([string]$text, [string]$Preffix, [System.ConsoleColor]$color) {
    return [ConsoleWriter]::Write($text, $Preffix, $color, [ConsoleWriter]::UseTypingEffect)
  }
  static [string] write([string]$text, [string]$Preffix, [System.ConsoleColor]$color, [bool]$Animate) {
    return [ConsoleWriter]::Write($text, $Preffix, 20, 1200, $color, $Animate, [ConsoleWriter]::LeadPreffix)
  }
  static [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [bool]$AddPreffix) {
    return [ConsoleWriter]::Write($text, $Preffix, $Speed, $Duration, [ConsoleColor]::White, [ConsoleWriter]::UseTypingEffect, $AddPreffix)
  }
  static [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix) {
    return [ConsoleWriter]::Write($text, $Preffix, $Speed, $Duration, $color, $Animate, $AddPreffix, [ConsoleWriter]::ValidateScript)
  }
  static [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix, [scriptblock]$ValidateScript) {
    if ($null -ne $ValidateScript) {
      [void]$ValidateScript.Invoke($text)
    } elseif ([string]::IsNullOrWhiteSpace($text)) {
      return $text
    }
    [int]$length = $text.Length; $delay = 0
    # Check if delay time is required:
    $delayIsRequired = if ($length -lt 50) { $false } else { $delay = $Duration - $length * $Speed; $delay -gt 0 }
    if ($AddPreffix -and ![string]::IsNullOrEmpty($Preffix)) {
      [void][ConsoleWriter]::Write($Preffix, [string]::Empty, 1, 100, [ConsoleColor]::Green, $false, $false);
    }
    $FgColr = [Console]::ForegroundColor
    [Console]::ForegroundColor = $color; $hostUI = (Get-Host).UI
    if ($Animate) {
      for ($i = 0; $i -lt $length; $i++) {
        $hostUI.Write($text[$i]);
        Start-Sleep -Milliseconds $Speed;
      }
    } else {
      $hostUI.Write($text);
    }
    if ($delayIsRequired) {
      Start-Sleep -Milliseconds $delay
    }
    [Console]::ForegroundColor = $FgColr
    return $text
  }
  static [byte[]] Encode([string]$text) { return [System.Text.Encoding]::UTF8.GetBytes($text) }
  static [string[]] get_ColorNames() {
    return [RGB].GetMethods().Where({ $_.IsStatic -and $_.Name -like "Get_*" }).Name.Substring(4)
  }
  static [int] get_ConsoleWidth() {
    # Force a refresh of the console information
    [System.Console]::SetCursorPosition([System.Console]::CursorLeft, [System.Console]::CursorTop)
    return [System.Console]::WindowWidth
  }
  hidden [System.Text.Encoding] get_Encoding() { return [System.Text.Encoding]::UTF8 }
  static [void] Clear() {
    [System.Console]::Clear()
  }
  static [void] SetCursorPosition([int]$X, [int]$Y) {
    [System.Console]::SetCursorPosition($X, $Y)
  }
  static [void] SetCursorPosition([ConsoleCoordinate]$Coordinate) {
    [System.Console]::SetCursorPosition($Coordinate.X, $Coordinate.Y)
  }
  static [void] ResetColor() {
    [System.Console]::ResetColor()
  }
  static [void] WriteLine([string]$text) {
    [void][ConsoleWriter]::Write($text)
    [System.Console]::WriteLine()
  }
  static [void] WriteLine([string]$text, [ConsoleColor]$color) {
    [void][ConsoleWriter]::Write($text, $color)
    [System.Console]::WriteLine()
  }
}

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

  [AnsiWriter] get_Writer() { return $this._writer }


  [void] Clear() {
    $this.Clear($true)
  }

  [void] Clear([bool]$_Home) {
    [Monitor]::Enter($this._renderLock)
    try {
      if ($this._writer.Capabilities.Ansi) {
        $this._writer.Write("`e[2J")
        if ($_Home) {
          $this._writer.Write("`e[H")
        }
      } else {
        [Console]::Clear()
      }
    } finally {
      [Monitor]::Exit($this._renderLock)
    }
  }

  [void] Write([IRenderable]$renderable) {
    if ($null -eq $renderable) {
      return
    }

    [Monitor]::Enter($this._renderLock)
    try {
      [ConsoleRenderer]::Render($this, $renderable)
    } finally {
      [Monitor]::Exit($this._renderLock)
    }
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

  [void] WriteLine([string]$text) {
    $this.WriteObject($text)
    $this._writer.WriteLine()
  }
}

class AnsiConsole {
  static [IAnsiConsole] $Console

  static AnsiConsole() {
    [AnsiConsole]::Reset()
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

  static [void] Reset() {
    [AnsiConsole]::Console = [AnsiConsoleFactory]::Create([AnsiConsoleSettings]::new())
  }
}

class AnsiConsoleFactory {
  static [IAnsiConsole] Create([AnsiConsoleSettings]$settings) {
    if ($null -eq $settings) {
      $settings = [AnsiConsoleSettings]::new()
    }

    if ($null -eq $settings.Out) {
      $settings.Out = [AnsiConsoleOutput]::new([Console]::Out)
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
  [System.IO.TextWriter]$Writer
  AnsiConsoleOutput([System.IO.TextWriter]$writer) {
    $this.Writer = $writer
  }
}

class AnsiConsoleSettings {
  [AnsiSupport]$Ansi = [AnsiSupport]::Detect
  [ColorSystemSupport]$ColorSystem = [ColorSystemSupport]::Detect
  [AnsiConsoleOutput]$Out = [AnsiConsoleOutput]::new([System.Console]::Out)
}

class Profile {
  [AnsiCapabilities]$Capabilities
  [AnsiConsoleOutput]$Out
  [int]$Width
  [int]$Height

  Profile() {
    $this.Capabilities = [AnsiCapabilities]::new()
    $this.Out = [AnsiConsoleOutput]::new([Console]::Out)
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

