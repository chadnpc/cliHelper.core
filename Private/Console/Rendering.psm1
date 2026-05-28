using namespace System
using namespace System.Collections.Generic
using namespace System.Collections
using namespace System.Text

using module ..\Enums.psm1
using module ..\Abstracts.psm1
using module .\Colors.psm1
using module .\Internal.psm1

class RenderableExtensions {
}

class RenderHookScope : IDisposable {
  [void] Dispose() { }
}


class Style {
  [Color]$Foreground
  [Color]$Background
  [Decoration]$Decoration

  static [Style] $Plain

  static Style() {
    [Style]::Plain = [Style]::new([Color]::Default, [Color]::Default, [Decoration]::None)
  }

  Style() {
    $this.Foreground = [Color]::Default
    $this.Background = [Color]::Default
    $this.Decoration = [Decoration]::None
  }

  Style([Color]$foreground) {
    $this.Foreground = ($null -ne $foreground) ? $foreground : [Color]::Default
    $this.Background = [Color]::Default
    $this.Decoration = [Decoration]::None
  }

  Style([Color]$foreground, [Color]$background, [Decoration]$decoration) {
    $this.Foreground = ($null -ne $foreground) ? $foreground : [Color]::Default
    $this.Background = ($null -ne $background) ? $background : [Color]::Default
    $this.Decoration = $decoration
  }

  static [Style] Parse([string]$text) {
    return [MarkupStyleParser]::ParseStyle($text)
  }

  static [bool] TryParse([string]$text, [ref]$result) {
    try {
      $result.Value = [Style]::Parse($text)
      return $true
    } catch {
      $result.Value = [Style]::Plain
      return $false
    }
  }

  [Style] Combine([Style]$other) {
    if ($null -eq $other) {
      return [Style]::new($this.Foreground, $this.Background, $this.Decoration)
    }

    $_foreground = $this.Foreground
    if ($null -ne $other.Foreground -and !$other.Foreground.IsDefault) {
      $_foreground = $other.Foreground
    }

    $_background = $this.Background
    if ($null -ne $other.Background -and !$other.Background.IsDefault) {
      $_background = $other.Background
    }

    return [Style]::new($_foreground, $_background, ($this.Decoration -bor $other.Decoration))
  }

  [string] ToMarkup() {
    $builder = [List[string]]::new()
    if ($this.Decoration -ne [Decoration]::None) {
      $builder.AddRange([MarkupStyleParser]::GetMarkupNames($this.Decoration))
    }
    if (!$this.Foreground.IsDefault) {
      $builder.Add($this.Foreground.ToMarkup())
    }
    if (!$this.Background.IsDefault) {
      if ($builder.Count -eq 0) { $builder.Add("default") }
      $builder.Add("on " + $this.Background.ToMarkup())
    }
    return [string]::Join(" ", $builder)
  }

  [string] ToString() {
    return $this.ToMarkup()
  }
}


class Segment {
  [string]$Text
  [Style]$Style
  [bool]$IsLineBreak
  [bool]$IsWhiteSpace
  [bool]$IsControlCode

  static [Segment] $LineBreak
  static [Segment] $Empty

  static Segment() {
    [Segment]::LineBreak = [Segment]::new("`n", [Style]::Plain, $true, $false)
    [Segment]::Empty = [Segment]::new([string]::Empty, [Style]::Plain, $false, $false)
  }

  Segment([string]$text) {
    [void]$this.Init($text, [Style]::Plain, $false, $false)
  }

  Segment([string]$text, [Style]$style) {
    [void]$this.Init($text, $style, $false, $false)
  }

  hidden [void] Init([string]$text, [Style]$style, [bool]$lineBreak, [bool]$control) {
    if ($null -eq $text) { throw [ArgumentNullException]::new("text") }
    $this.Text = $text
    $this.Style = ($null -ne $style) ? $style : [Style]::Plain
    $this.IsLineBreak = $lineBreak
    $this.IsWhiteSpace = [string]::IsNullOrWhiteSpace($text)
    $this.IsControlCode = $control
  }

  Segment([string]$text, [Style]$style, [bool]$lineBreak, [bool]$control) {
    [void]$this.Init($text, $style, $lineBreak, $control)
  }

  static [Segment] Padding([int]$size) {
    return [Segment]::new((' ' * $size))
  }

  static [Segment] Control([string]$control) {
    return [Segment]::new($control, [Style]::Plain, $false, $true)
  }

  [int] CellCount() {
    if ($this.IsControlCode) { return 0 }
    if ($this.Text -eq "`n") { return 1 }
    return [Cell]::GetCellLength($this.Text)
  }

  static [int] CellCount([IEnumerable]$segments) {
    if ($null -eq $segments) { return 0 }
    $sum = 0
    foreach ($segment in $segments) {
      $sum += $segment.CellCount()
    }
    return $sum
  }

  [ValueTuple[Segment, Segment]] Split([int]$offset) {
    $count = $this.CellCount()
    if ($offset -le 0) { return [ValueTuple[Segment, Segment]]::new($null, $this) }
    if ($offset -ge $count) { return [ValueTuple[Segment, Segment]]::new($this, $null) }

    # Simple split based on string length for now.
    # TODO: Improve this to handle cluster boundaries.
    $firstText = $this.Text.Substring(0, $offset)
    $secondText = $this.Text.Substring($offset)
    return [ValueTuple[Segment, Segment]]::new(
      [Segment]::new($firstText, $this.Style, $this.IsLineBreak, $this.IsControlCode),
      [Segment]::new($secondText, $this.Style, $this.IsLineBreak, $this.IsControlCode)
    )
  }

  static [List[Segment]] Truncate([IEnumerable]$segments, [int]$maxWidth) {
    $result = [List[Segment]]::new()
    $currentLength = 0
    foreach ($seg in $segments) {
      if ($null -eq $seg -or $seg -isnot [Segment]) { continue }
      $segLen = $seg.CellCount()
      if ($currentLength + $segLen -le $maxWidth) {
        $result.Add($seg)
        $currentLength += $segLen
      } else {
        $offset = $maxWidth - $currentLength
        if ($offset -gt 0) {
          $split = $seg.Split($offset)
          if ($null -ne $split.Item1) { $result.Add($split.Item1) }
        }
        break
      }
    }
    return $result
  }
  static [List[SegmentLine]] SplitLines([Segment[]]$segments, [int]$maxWidth) {
    return [Segment]::SplitLines((, $segments), $maxWidth)
  }
  static [List[SegmentLine]] SplitLines([IEnumerable]$segments, [int]$maxWidth) {
    $list = [List[Segment]]::new()
    if ($null -ne $segments) {
      foreach ($s in $segments) {
        if ($null -eq $s) { continue }
        if ($s -is [Segment]) {
          $list.Add([Segment]$s)
        } elseif ($s -is [IEnumerable]) {
          foreach ($inner in $s) {
            if ($null -ne $inner -and $inner -is [Segment]) {
              $list.Add([Segment]$inner)
            }
          }
        }
      }
    }
    $lines = [List[SegmentLine]]::new()
    $currentLine = [SegmentLine]::new()

    # Reverse stack because we pop from top
    $list.Reverse()
    $stack = [Stack]::new($list)
    while ($stack.Count -gt 0) {
      $segment = $stack.Pop()
      $segmentLength = $segment.CellCount()
      $lineLength = $currentLine.CellCount()

      if ($lineLength + $segmentLength -gt $maxWidth) {
        $offset = $maxWidth - $lineLength
        if ($offset -gt 0) {
          $split = $segment.Split($offset)
          if ($null -ne $split.Item1) { $currentLine.Add($split.Item1) }
          $lines.Add($currentLine)
          $currentLine = [SegmentLine]::new()
          if ($null -ne $split.Item2) { $stack.Push($split.Item2) }
        } else {
          $lines.Add($currentLine)
          $currentLine = [SegmentLine]::new()
          $stack.Push($segment)
        }
        continue
      }

      if ($segment.Text.Contains("`n")) {
        $parts = $segment.Text.Split("`n")
        for ($i = 0; $i -lt $parts.Length; $i++) {
          if ($parts[$i].Length -gt 0) {
            $currentLine.Add([Segment]::new($parts[$i], $segment.Style))
          }
          if ($i -lt $parts.Length - 1) {
            $lines.Add($currentLine)
            $currentLine = [SegmentLine]::new()
          }
        }
      } else {
        $currentLine.Add($segment)
      }
    }

    if ($currentLine.Count() -gt 0) {
      $lines.Add($currentLine)
    }

    return $lines
  }

  [string] ToString() { return $this.Text }
}

class SegmentLine {
  [List[Segment]]$Segments
  SegmentLine() { $this.Segments = [List[Segment]]::new() }
  SegmentLine([IEnumerable[Segment]]$segments) { $this.Segments = [List[Segment]]::new($segments) }

  [void] Add([Segment]$segment) { $this.Segments.Add($segment) }
  [int] CellCount() { return [Segment]::CellCount($this.Segments) }
  [int] Count() { return $this.Segments.Count }

  [string] ToString() {
    $sb = [StringBuilder]::new()
    foreach ($s in $this.Segments) { [void]$sb.Append($s.Text) }
    return $sb.ToString()
  }
}

class MarkupSegmentInfo {
  [string]$Text
  [Style]$Style
  [string]$Link

  MarkupSegmentInfo([string]$text, [Style]$style, [string]$link) {
    $this.Text = $text
    $this.Style = ($null -ne $style) ? $style : [Style]::Plain
    $this.Link = $link
  }
}

class MarkupStyleState {
  [Style]$Style
  [string]$Link

  MarkupStyleState([Style]$style, [string]$link) {
    $this.Style = ($null -ne $style) ? $style : [Style]::Plain
    $this.Link = $link
  }
}

class MarkupStyleStateDelta {
  [Style]$Style
  [string]$Link

  MarkupStyleStateDelta([Style]$style, [string]$link) {
    $this.Style = ($null -ne $style) ? $style : [Style]::Plain
    $this.Link = $link
  }
}

class MarkupStyleParser {
  static [Nullable[Decoration]] GetDecoration([string]$name) {
    switch ($name.ToLowerInvariant()) {
      'none' { return [Decoration]::None }
      'bold' { return [Decoration]::Bold }
      'b' { return [Decoration]::Bold }
      'dim' { return [Decoration]::Dim }
      'italic' { return [Decoration]::Italic }
      'i' { return [Decoration]::Italic }
      'underline' { return [Decoration]::Underline }
      'u' { return [Decoration]::Underline }
      'invert' { return [Decoration]::Invert }
      'reverse' { return [Decoration]::Invert }
      'conceal' { return [Decoration]::Conceal }
      'blink' { return [Decoration]::SlowBlink }
      'slowblink' { return [Decoration]::SlowBlink }
      'rapidblink' { return [Decoration]::RapidBlink }
      'strike' { return [Decoration]::Strikethrough }
      'strikethrough' { return [Decoration]::Strikethrough }
      's' { return [Decoration]::Strikethrough }
      default { return $null }
    }

    return $null
  }

  static [System.Collections.Generic.List[string]] GetMarkupNames([Decoration]$decoration) {
    $result = [System.Collections.Generic.List[string]]::new()
    $lookup = [ordered]@{
      Bold          = 'bold'
      Dim           = 'dim'
      Italic        = 'italic'
      Underline     = 'underline'
      Invert        = 'invert'
      Conceal       = 'conceal'
      SlowBlink     = 'blink'
      RapidBlink    = 'rapidblink'
      Strikethrough = 'strikethrough'
    }

    foreach ($key in $lookup.Keys) {
      $flag = [Decoration]::$key
      if (($decoration -band $flag) -eq $flag) {
        $result.Add($lookup[$key])
      }
    }

    return $result
  }

  static [Style] ParseStyle([string]$text) {
    $delta = [MarkupStyleParser]::ParseTagState($text)
    return $delta.Style
  }

  static [MarkupStyleStateDelta] ParseTagState([string]$tag) {
    if ([string]::IsNullOrWhiteSpace($tag)) {
      return [MarkupStyleStateDelta]::new([Style]::Plain, $null)
    }

    $foreground = [Color]::Default
    $background = [Color]::Default
    $decoration = [Decoration]::None
    $link = $null
    $parts = $tag.Split(' ', [StringSplitOptions]::RemoveEmptyEntries)
    $isBackground = $false

    foreach ($rawPart in $parts) {
      $part = $rawPart.Trim()
      if ([string]::IsNullOrWhiteSpace($part)) {
        continue
      }

      if ($part -ieq 'on') {
        $isBackground = $true
        continue
      }

      if ($part.StartsWith('link=', [StringComparison]::OrdinalIgnoreCase)) {
        $link = $part.Substring(5)
        continue
      }

      $matchedDecoration = $true
      switch ($part.ToLowerInvariant()) {
        'none' { }
        'bold' { $decoration = $decoration -bor [Decoration]::Bold }
        'b' { $decoration = $decoration -bor [Decoration]::Bold }
        'dim' { $decoration = $decoration -bor [Decoration]::Dim }
        'italic' { $decoration = $decoration -bor [Decoration]::Italic }
        'i' { $decoration = $decoration -bor [Decoration]::Italic }
        'underline' { $decoration = $decoration -bor [Decoration]::Underline }
        'u' { $decoration = $decoration -bor [Decoration]::Underline }
        'invert' { $decoration = $decoration -bor [Decoration]::Invert }
        'reverse' { $decoration = $decoration -bor [Decoration]::Invert }
        'conceal' { $decoration = $decoration -bor [Decoration]::Conceal }
        'blink' { $decoration = $decoration -bor [Decoration]::SlowBlink }
        'slowblink' { $decoration = $decoration -bor [Decoration]::SlowBlink }
        'rapidblink' { $decoration = $decoration -bor [Decoration]::RapidBlink }
        'strike' { $decoration = $decoration -bor [Decoration]::Strikethrough }
        'strikethrough' { $decoration = $decoration -bor [Decoration]::Strikethrough }
        's' { $decoration = $decoration -bor [Decoration]::Strikethrough }
        default { $matchedDecoration = $false }
      }

      if ($matchedDecoration) {
        continue
      }
      $color = if ($part.StartsWith('#')) { [Color]::FromHex($part) } else { [Color]::FromName($part) }
      if ($null -ne $color) {
        if ($isBackground) {
          $background = $color
        } else {
          $foreground = $color
        }
        continue
      }

      throw "Unsupported markup token '$part'."
    }

    return [MarkupStyleStateDelta]::new([Style]::new($foreground, $background, $decoration), $link)
  }

  static [List[MarkupSegmentInfo]] ParseMarkup([string]$markup, [Style]$baseStyle) {
    $result = [List[MarkupSegmentInfo]]::new()
    if ($null -eq $markup) {
      return $result
    }

    $style = if ($null -ne $baseStyle) { $baseStyle } else { [Style]::Plain }
    $styleStack = [Stack[MarkupStyleState]]::new()
    $buffer = [StringBuilder]::new()
    $link = $null
    $index = 0

    while ($index -lt $markup.Length) {
      $current = $markup[$index]

      if ($current -eq '[') {
        if (($index + 1) -lt $markup.Length -and $markup[$index + 1] -eq '[') {
          [void]$buffer.Append('[')
          $index += 2
          continue
        }

        if ($buffer.Length -gt 0) {
          [MarkupStyleParser]::AppendSegment($result, $buffer.ToString(), $style, $link)
          [void]$buffer.Clear()
        }

        $closeIndex = [MarkupStyleParser]::FindTagEnd($markup, $index + 1)
        if ($closeIndex -lt 0) {
          throw "Encountered malformed markup tag at position $index."
        }

        $tag = $markup.Substring($index + 1, $closeIndex - $index - 1)
        if ($tag -eq '/') {
          if ($styleStack.Count -eq 0) {
            throw "Encountered closing tag when none was expected near position $index."
          }

          $state = $styleStack.Pop()
          $style = $state.Style
          $link = $state.Link
        } else {
          $styleStack.Push([MarkupStyleState]::new($style, $link))
          $delta = [MarkupStyleParser]::ParseTagState($tag)
          $style = $style.Combine($delta.Style)
          if (-not [string]::IsNullOrWhiteSpace($delta.Link)) {
            $link = $delta.Link
          }
        }

        $index = $closeIndex + 1
        continue
      }

      if ($current -eq ']') {
        if (($index + 1) -lt $markup.Length -and $markup[$index + 1] -eq ']') {
          [void]$buffer.Append(']')
          $index += 2
          continue
        }

        throw "Encountered unescaped ']' token at position $index."
      }

      [void]$buffer.Append($current)
      $index++
    }

    if ($buffer.Length -gt 0) {
      [MarkupStyleParser]::AppendSegment($result, $buffer.ToString(), $style, $link)
    }

    if ($styleStack.Count -gt 0) {
      Write-Warning "[MarkupStyleParser]::ParseMarkup - Failed! Unbalanced markup stack. Did you forget to close a tag?"
    }

    return $result
  }

  static [string] RemoveMarkup([string]$markup) {
    if ([string]::IsNullOrWhiteSpace($markup)) {
      return [string]::Empty
    }

    $builder = [StringBuilder]::new()
    foreach ($segment in [MarkupStyleParser]::ParseMarkup($markup, [Style]::Plain)) {
      [void]$builder.Append($segment.Text)
    }
    return $builder.ToString()
  }

  static [string] Escape([string]$markup) {
    if ($null -eq $markup) {
      return [string]::Empty
    }

    return $markup.Replace('[', '[[').Replace(']', ']]')
  }

  static hidden [void] AppendSegment([List[MarkupSegmentInfo]]$segments, [string]$text, [Style]$style, [string]$link) {
    if ([string]::IsNullOrEmpty($text)) {
      return
    }

    if ($segments.Count -gt 0) {
      $last = $segments[$segments.Count - 1]
      if ($last.Style.ToMarkup() -eq $style.ToMarkup() -and $last.Link -eq $link) {
        $last.Text += $text
        return
      }
    }

    $segments.Add([MarkupSegmentInfo]::new($text, $style, $link))
  }

  static hidden [int] FindTagEnd([string]$markup, [int]$startIndex) {
    $index = $startIndex
    while ($index -lt $markup.Length) {
      if ($markup[$index] -eq ']') {
        return $index
      }
      $index++
    }
    return -1
  }
}
