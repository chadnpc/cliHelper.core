using namespace System
using namespace System.Collections.Generic

using module .\Enums.psm1
using module .\Colors.psm1


class Cell {
  static [int] GetCellLength([string]$text) {
    if ([string]::IsNullOrEmpty($text)) { return 0 }
    # Simple implementation: account for surrogate pairs using StringInfo.
    # Note: This doesn't handle full-width characters (CJK) or emojis perfectly,
    # but it's a good start for a core engine.
    $enumerator = [Globalization.StringInfo]::GetTextElementEnumerator($text)
    $sum = 0
    while ($enumerator.MoveNext()) {
      $sum++
    }
    return $sum
  }
}

class Constants {
}

class DecorationTable {
  static hidden [System.Collections.Generic.Dictionary[string, [Nullable[Decoration]]]] $_lookup
  static hidden [System.Collections.Generic.Dictionary[Decoration, string]] $_reverseLookup

  static DecorationTable() {
    $dict = [System.Collections.Generic.Dictionary[string, [Nullable[Decoration]]]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $dict.Add("none", [Decoration]::None)
    $dict.Add("bold", [Decoration]::Bold)
    $dict.Add("b", [Decoration]::Bold)
    $dict.Add("dim", [Decoration]::Dim)
    $dict.Add("italic", [Decoration]::Italic)
    $dict.Add("i", [Decoration]::Italic)
    $dict.Add("underline", [Decoration]::Underline)
    $dict.Add("u", [Decoration]::Underline)
    $dict.Add("invert", [Decoration]::Invert)
    $dict.Add("reverse", [Decoration]::Invert)
    $dict.Add("conceal", [Decoration]::Conceal)
    $dict.Add("blink", [Decoration]::SlowBlink)
    $dict.Add("slowblink", [Decoration]::SlowBlink)
    $dict.Add("rapidblink", [Decoration]::RapidBlink)
    $dict.Add("strike", [Decoration]::Strikethrough)
    $dict.Add("strikethrough", [Decoration]::Strikethrough)
    $dict.Add("s", [Decoration]::Strikethrough)
    [DecorationTable]::_lookup = $dict

    $rev = [System.Collections.Generic.Dictionary[Decoration, string]]::new()
    foreach ($pair in $dict) {
      if ($pair.Value.HasValue -and $pair.Value.Value -ne [Decoration]::None) {
        if (!$rev.ContainsKey($pair.Value.Value)) {
          $rev.Add($pair.Value.Value, $pair.Key)
        }
      }
    }
    [DecorationTable]::_reverseLookup = $rev
  }

  static [Nullable[Decoration]] GetDecoration([string]$name) {
    if ([DecorationTable]::_lookup.ContainsKey($name)) {
      return [DecorationTable]::_lookup[$name]
    }
    return $null
  }

  static [System.Collections.Generic.List[string]] GetMarkupNames([Decoration]$decoration) {
    $result = [System.Collections.Generic.List[string]]::new()
    foreach ($value in [Enum]::GetValues([Decoration])) {
      $flag = [Decoration]$value
      if ($flag -ne [Decoration]::None -and ($decoration -band $flag) -eq $flag) {
        if ([DecorationTable]::_reverseLookup.ContainsKey($flag)) {
          $result.Add([DecorationTable]::_reverseLookup[$flag])
        }
      }
    }
    return $result
  }
}


class DefaultExclusivityMode : IExclusivityMode {
}


class ResourceReader {
}

class TypeConverterHelper {
}

class NoopCursor : IAnsiConsoleCursor {
}

class NoopExclusivityMode : IExclusivityMode {
}

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
  hidden [string] $LeadPreffix
  static hidden [string[]] $Colors = [ConsoleWriter]::get_ColorNames()
  hidden [ValidateNotNull()][scriptblock]$ValidateScript = { param($arg) if ([String]::IsNullOrEmpty($arg)) { throw [ArgumentNullException]::new('text', 'Cannot be Null Or Empty') } }

  ConsoleWriter() : base() {
    $this.PsObject.Properties.Add([psscriptproperty]::new("UseLeadPreffix", { return ![string]::IsNullOrWhiteSpace($this.LeadPreffix) }))
    $this.PsObject.Properties.Add([PsNoteProperty]::new("UseTypingEffect", $false ))
  }

  [string] write([string]$text) {
    return $this.Write($text, 20, 1200)
  }
  [string] write([string]$text, [bool]$AddPreffix) {
    return $this.Write($text, 20, 1200, $AddPreffix)
  }
  [string] write([string]$text, [int]$Speed, [int]$Duration) {
    return $this.Write($text, 20, 1200, $this.UseLeadPreffix)
  }
  [string] write([string]$text, [ConsoleColor]$color) {
    return $this.Write($text, $color, $this.UseTypingEffect)
  }
  [string] write([string]$text, [ConsoleColor]$color, [bool]$Animate) {
    return $this.Write($text, $this.LeadPreffix, 20, 1200, $color, $Animate, $this.LeadPreffix)
  }
  [string] write([string]$text, [int]$Speed, [int]$Duration, [bool]$AddPreffix) {
    return $this.Write($text, $this.LeadPreffix, $Speed, $Duration, [ConsoleColor]::White, $this.UseTypingEffect, $AddPreffix)
  }
  [string] write([string]$text, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix) {
    return $this.Write($text, $this.LeadPreffix, 20, 1200, $color, $Animate, $AddPreffix)
  }
  [string] write([string]$text, [string]$Preffix, [System.ConsoleColor]$color) {
    return $this.Write($text, $Preffix, $color, $this.UseTypingEffect)
  }
  [string] write([string]$text, [string]$Preffix, [System.ConsoleColor]$color, [bool]$Animate) {
    return $this.Write($text, $Preffix, 20, 1200, $color, $Animate, $this.LeadPreffix)
  }
  [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [bool]$AddPreffix) {
    return $this.Write($text, $Preffix, $Speed, $Duration, [ConsoleColor]::White, $this.UseTypingEffect, $AddPreffix)
  }
  [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix) {
    return $this.Write($text, $Preffix, $Speed, $Duration, $color, $Animate, $AddPreffix, $this.ValidateScript)
  }
  [string] write([string]$text, [string]$Preffix, [int]$Speed, [int]$Duration, [ConsoleColor]$color, [bool]$Animate, [bool]$AddPreffix, [scriptblock]$ValidateScript) {
    if ($null -ne $ValidateScript) {
      [void]$ValidateScript.Invoke($text)
    } elseif ([string]::IsNullOrWhiteSpace($text)) {
      return $text
    }
    [int]$length = $text.Length; $delay = 0
    # Check if delay time is required:
    $delayIsRequired = if ($length -lt 50) { $false } else { $delay = $Duration - $length * $Speed; $delay -gt 0 }
    if ($AddPreffix -and ![string]::IsNullOrEmpty($Preffix)) {
      [void]$this.Write($Preffix, [string]::Empty, 1, 100, [ConsoleColor]::Green, $false, $false);
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
  static [byte[]] Encode([string]$text) {
    return [System.Text.Encoding]::UTF8.GetBytes($text)
  }
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
  [void] WriteLine([string]$text) {
    [void]$this.Write($text)
    [System.Console]::WriteLine()
  }
  [void] WriteLine([string]$text, [ConsoleColor]$color) {
    [void]$this.Write($text, $color)
    [System.Console]::WriteLine()
  }
}