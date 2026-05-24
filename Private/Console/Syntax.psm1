using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Globalization
using namespace System.Text

using module .\Colors.psm1
using module .\Enums.psm1
using module .\Rendering.psm1

class JsonSyntax : IRenderable {
  static [Style]$PunctuationStyle = [Style]::new([Color]::FromName('Grey62'))
  static [Style]$MemberStyle = [Style]::new([Color]::FromName('DeepSkyBlue1'))
  static [Style]$StringStyle = [Style]::new([Color]::FromName('SpringGreen3'))
  static [Style]$NumberStyle = [Style]::new([Color]::FromName('MediumPurple1'))
  static [Style]$BooleanStyle = [Style]::new([Color]::FromName('Yellow1'))
  static [Style]$NullStyle = [Style]::new([Color]::FromName('Grey58'), [Color]::Default, [Decoration]::Italic)

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    $max = 0
    foreach ($line in [Segment]::SplitLines($this.Render($options, [Math]::Max(1, $maxWidth)), [Math]::Max(1, $maxWidth))) {
      $max = [Math]::Max($max, $line.CellCount())
    }
    return [Measurement]::new([Math]::Min($max, $maxWidth), [Math]::Min($max, $maxWidth))
  }

  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    $segments = [List[Segment]]::new()
    $this.Write($segments, 0)
    return $segments.ToArray()
  }

  [void] Write([List[Segment]]$segments, [int]$indent) { }

  static [JsonSyntax] FromObject([object]$value) {
    if ($null -eq $value) { return [JsonNull]::new() }

    if ($value -is [JsonSyntax]) { return [JsonSyntax]$value }
    if ($value -is [string] -or $value -is [char]) { return [JsonString]::new([string]$value) }
    if ($value -is [bool]) { return [JsonBoolean]::new([bool]$value) }
    if ([JsonSyntax]::IsNumber($value)) { return [JsonNumber]::new($value) }

    if ($value -is [IDictionary]) {
      $object = [JsonObject]::new()
      foreach ($key in ([IDictionary]$value).Keys) {
        $object.Add([string]$key, [JsonSyntax]::FromObject(([IDictionary]$value)[$key]))
      }
      return $object
    }

    if ($value -is [psobject] -and $value.psobject.Properties.Count -gt 0 -and $value -isnot [IEnumerable]) {
      $object = [JsonObject]::new()
      foreach ($property in $value.psobject.Properties) {
        $object.Add($property.Name, [JsonSyntax]::FromObject($property.Value))
      }
      return $object
    }

    if ($value -is [IEnumerable] -and $value -isnot [string]) {
      $array = [JsonArray]::new()
      foreach ($item in [IEnumerable]$value) {
        $array.Add([JsonSyntax]::FromObject($item))
      }
      return $array
    }

    return [JsonString]::new($value.ToString())
  }

  static hidden [bool] IsNumber([object]$value) {
    return $value -is [byte] -or $value -is [sbyte] -or
    $value -is [int16] -or $value -is [uint16] -or
    $value -is [int] -or $value -is [uint32] -or
    $value -is [long] -or $value -is [uint64] -or
    $value -is [single] -or $value -is [double] -or
    $value -is [decimal]
  }

  static hidden [void] AddIndent([List[Segment]]$segments, [int]$indent) {
    if ($indent -gt 0) { $segments.Add([Segment]::new(' ' * $indent, [Style]::Plain)) }
  }

  static hidden [string] EscapeString([string]$value) {
    if ($null -eq $value) { return '' }
    $builder = [StringBuilder]::new()
    foreach ($ch in $value.ToCharArray()) {
      switch ($ch) {
        '"' { [void]$builder.Append('\"'); break }
        '\' { [void]$builder.Append('\\'); break }
        "`b" { [void]$builder.Append('\b'); break }
        "`f" { [void]$builder.Append('\f'); break }
        "`n" { [void]$builder.Append('\n'); break }
        "`r" { [void]$builder.Append('\r'); break }
        "`t" { [void]$builder.Append('\t'); break }
        default {
          if ([char]::IsControl($ch)) {
            [void]$builder.Append('\u{0:x4}' -f [int]$ch)
          } else {
            [void]$builder.Append($ch)
          }
        }
      }
    }
    return $builder.ToString()
  }
}

class JsonArray : JsonSyntax {
  [List[JsonSyntax]]$Items

  JsonArray() {
    $this.Items = [List[JsonSyntax]]::new()
  }

  [void] Add([JsonSyntax]$item) {
    $this.Items.Add(($null -ne $item) ? $item : [JsonNull]::new())
  }

  [void] Write([List[Segment]]$segments, [int]$indent) {
    $segments.Add([Segment]::new('[', [JsonSyntax]::PunctuationStyle))
    if ($this.Items.Count -eq 0) {
      $segments.Add([Segment]::new(']', [JsonSyntax]::PunctuationStyle))
      return
    }

    for ($i = 0; $i -lt $this.Items.Count; $i++) {
      $segments.Add([Segment]::LineBreak)
      [JsonSyntax]::AddIndent($segments, $indent + 2)
      $this.Items[$i].Write($segments, $indent + 2)
      if ($i -lt $this.Items.Count - 1) {
        $segments.Add([Segment]::new(',', [JsonSyntax]::PunctuationStyle))
      }
    }

    $segments.Add([Segment]::LineBreak)
    [JsonSyntax]::AddIndent($segments, $indent)
    $segments.Add([Segment]::new(']', [JsonSyntax]::PunctuationStyle))
  }
}

class JsonBoolean : JsonSyntax {
  [bool]$Value
  JsonBoolean([bool]$value) { $this.Value = $value }
  [void] Write([List[Segment]]$segments, [int]$indent) {
    $segments.Add([Segment]::new($this.Value.ToString().ToLowerInvariant(), [JsonSyntax]::BooleanStyle))
  }
}

class JsonMember : JsonSyntax {
  [string]$Name
  [JsonSyntax]$Value

  JsonMember([string]$name, [JsonSyntax]$value) {
    $this.Name = $name
    $this.Value = ($null -ne $value) ? $value : [JsonNull]::new()
  }

  [void] Write([List[Segment]]$segments, [int]$indent) {
    $segments.Add([Segment]::new('"' + [JsonSyntax]::EscapeString($this.Name) + '"', [JsonSyntax]::MemberStyle))
    $segments.Add([Segment]::new(': ', [JsonSyntax]::PunctuationStyle))
    $this.Value.Write($segments, $indent)
  }
}

class JsonNull : JsonSyntax {
  JsonNull() { }
  [void] Write([List[Segment]]$segments, [int]$indent) {
    $segments.Add([Segment]::new('null', [JsonSyntax]::NullStyle))
  }
}

class JsonNumber : JsonSyntax {
  [string]$Raw

  JsonNumber([object]$value) {
    if ($null -eq $value) {
      $this.Raw = '0'
    } elseif ($value -is [IFormattable]) {
      $this.Raw = ([IFormattable]$value).ToString($null, [CultureInfo]::InvariantCulture)
    } else {
      $this.Raw = $value.ToString()
    }
  }

  [void] Write([List[Segment]]$segments, [int]$indent) {
    $segments.Add([Segment]::new($this.Raw, [JsonSyntax]::NumberStyle))
  }
}

class JsonObject : JsonSyntax {
  [List[JsonMember]]$Members

  JsonObject() {
    $this.Members = [List[JsonMember]]::new()
  }

  [void] Add([string]$name, [JsonSyntax]$value) {
    $this.Members.Add([JsonMember]::new($name, $value))
  }

  [void] Write([List[Segment]]$segments, [int]$indent) {
    $segments.Add([Segment]::new('{', [JsonSyntax]::PunctuationStyle))
    if ($this.Members.Count -eq 0) {
      $segments.Add([Segment]::new('}', [JsonSyntax]::PunctuationStyle))
      return
    }

    for ($i = 0; $i -lt $this.Members.Count; $i++) {
      $segments.Add([Segment]::LineBreak)
      [JsonSyntax]::AddIndent($segments, $indent + 2)
      $this.Members[$i].Write($segments, $indent + 2)
      if ($i -lt $this.Members.Count - 1) {
        $segments.Add([Segment]::new(',', [JsonSyntax]::PunctuationStyle))
      }
    }

    $segments.Add([Segment]::LineBreak)
    [JsonSyntax]::AddIndent($segments, $indent)
    $segments.Add([Segment]::new('}', [JsonSyntax]::PunctuationStyle))
  }
}

class JsonString : JsonSyntax {
  [string]$Value
  JsonString([string]$value) { $this.Value = $value }
  [void] Write([List[Segment]]$segments, [int]$indent) {
    $segments.Add([Segment]::new('"' + [JsonSyntax]::EscapeString($this.Value) + '"', [JsonSyntax]::StringStyle))
  }
}
