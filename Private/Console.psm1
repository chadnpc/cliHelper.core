using namespace System
using namespace System.IO
using namespace System.Linq
using namespace System.Text
using namespace System.Diagnostics
using namespace System.Globalization
using namespace System.ComponentModel
using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
using namespace System.Runtime.InteropServices
using namespace System.Management.Automation

using module .\Console\Ansi.psm1
using module .\Console\AnsiConsole.psm1
using module .\Console\Boxes.psm1
using module .\Console\Charts.psm1
using module .\Console\Colors.psm1
using module .\Console\Emojis.psm1
using module .\Console\Enums.psm1
using module .\Console\Figlet.psm1
using module .\Console\Internal.psm1
using module .\Console\Json.psm1
using module .\Console\Layout.psm1
using module .\Console\List.psm1
using module .\Console\Live.psm1
using module .\Console\Progress.psm1
using module .\Console\Prompts.psm1
using module .\Console\Renderer.psm1
using module .\Console\Rendering.psm1
using module .\Console\Spinners.psm1
using module .\Console\Status.psm1
using module .\Console\Syntax.psm1
using module .\Console\Table.psm1
using module .\Console\TableRenderer.psm1
using module .\Console\Tables.psm1
using module .\Console\Tree.psm1
using module .\Console\Utilities.psm1
using module .\Console\Widgets.psm1

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


# Types that will be available to users when they import the module.
# Hint: To automatically generate typestoexport variable you can use this one liner to generate types to export variable
# (Get-ChildItem .\Private\Console\*.psm1 -Recurse -File | ForEach-Object { [IO.File]::ReadAllLines((Get-Item $_.FullName)).Where({ $_.StartsWith("class") -or $_.StartsWith("enum ") }).ForEach({ $_.Replace("class ", '[').Replace("enum ", '[') }).ForEach({ ($_ -like "* : *") ? $_.split(" : ")[0] + ']' : $_.Replace(' {', ']') }) }) -join ', '
