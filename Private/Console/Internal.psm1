using namespace System
using namespace System.Collections.Generic

using module .\Enums.psm1


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

class ConsoleHelper {
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

class Ratio {

}

class ResourceReader {
}

class TypeConverterHelper {
}
class NoopCursor : IAnsiConsoleCursor {
}

class NoopExclusivityMode : IExclusivityMode {
}

class FileSizeTests {
}

class WhiteSpaceSegmentEnumeratorTests {
}
