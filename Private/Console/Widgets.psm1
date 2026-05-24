using namespace System
using namespace System.Collections.Generic
using namespace System.Linq

using module .\Enums.psm1
using module .\Colors.psm1
using module .\Internal.psm1
using module .\Rendering.psm1
using module .\Ansi.psm1
using module .\Boxes.psm1

class Padding {
  [int]$Left
  [int]$Top
  [int]$Right
  [int]$Bottom

  Padding([int]$size) {
    $this.Left = $size
    $this.Top = $size
    $this.Right = $size
    $this.Bottom = $size
  }

  Padding([int]$horizontal, [int]$vertical) {
    $this.Left = $horizontal
    $this.Top = $vertical
    $this.Right = $horizontal
    $this.Bottom = $vertical
  }

  Padding([int]$left, [int]$top, [int]$right, [int]$bottom) {
    $this.Left = $left
    $this.Top = $top
    $this.Right = $right
    $this.Bottom = $bottom
  }

  [int] GetLeftSafe() { return [Math]::Max(0, $this.Left) }
  [int] GetTopSafe() { return [Math]::Max(0, $this.Top) }
  [int] GetRightSafe() { return [Math]::Max(0, $this.Right) }
  [int] GetBottomSafe() { return [Math]::Max(0, $this.Bottom) }
  [int] GetWidth() { return $this.GetLeftSafe() + $this.GetRightSafe() }
  [int] GetHeight() { return $this.GetTopSafe() + $this.GetBottomSafe() }
}

class Aligner {
  static [void] Align([List[Segment]]$segments, [Justify]$alignment, [int]$maxWidth) {
    if ($null -eq $alignment -or $alignment -eq [Justify]::Left) { return }
    $width = [Segment]::CellCount($segments)
    if ($width -ge $maxWidth) { return }

    switch ($alignment) {
      ([Justify]::Right) {
        $diff = $maxWidth - $width
        $segments.Insert(0, [Segment]::Padding($diff))
      }
      ([Justify]::Center) {
        $diff = [Math]::Floor(($maxWidth - $width) / 2)
        $segments.Insert(0, [Segment]::Padding($diff))
        $segments.Add([Segment]::Padding($diff))
        $remainder = ($maxWidth - $width) % 2
        if ($remainder -ne 0) { $segments.Add([Segment]::Padding($remainder)) }
      }
    }
  }

  static [void] AlignHorizontally([List[Segment]]$segments, [HorizontalAlignment]$alignment, [int]$maxWidth) {
    $width = [Segment]::CellCount($segments)
    if ($width -ge $maxWidth) { return }

    switch ($alignment) {
      ([HorizontalAlignment]::Left) {
        $diff = $maxWidth - $width
        $segments.Add([Segment]::Padding($diff))
      }
      ([HorizontalAlignment]::Right) {
        $diff = $maxWidth - $width
        $segments.Insert(0, [Segment]::Padding($diff))
      }
      ([HorizontalAlignment]::Center) {
        $diff = [Math]::Floor(($maxWidth - $width) / 2)
        $segments.Insert(0, [Segment]::Padding($diff))
        $segments.Add([Segment]::Padding($diff))
        $remainder = ($maxWidth - $width) % 2
        if ($remainder -ne 0) { $segments.Add([Segment]::Padding($remainder)) }
      }
    }
  }
}

class Paragraph : IRenderable {
  hidden [List[SegmentLine]]$_lines
  [Nullable[Justify]]$Justification
  [Nullable[Overflow]]$Overflow

  Paragraph() {
    $this._lines = [List[SegmentLine]]::new()
  }

  Paragraph([string]$text) {
    $this._lines = [List[SegmentLine]]::new()
    $this.Append($text, [Style]::Plain, $null)
  }

  Paragraph([string]$text, [Style]$style) {
    $this._lines = [List[SegmentLine]]::new()
    $this.Append($text, $style, $null)
  }

  [int] get_Length() {
    $len = 0
    foreach ($line in $this._lines) {
      foreach ($s in $line.Segments) { $len += $s.Text.Length }
    }
    return $len + [Math]::Max(0, $this._lines.Count - 1)
  }

  [int] get_Lines() {
    return $this._lines.Count
  }

  [void] Append([string]$text, [Style]$style, [AnsiLink]$link) {
    if ([string]::IsNullOrEmpty($text)) { return }
    if ($null -eq $style) { $style = [Style]::Plain }

    $first = $true
    $span = $text.Split("`n")
    foreach ($lineSpan in $span) {
      $lineSpan = $lineSpan.TrimEnd("`r")
      if (!$first -or $this._lines.Count -eq 0) {
        $line = [SegmentLine]::new()
        $this._lines.Add($line)
      } else {
        $line = $this._lines[$this._lines.Count - 1]
      }
      $first = $false

      if ([string]::IsNullOrEmpty($lineSpan)) {
        $line.Add([Segment]::Empty)
      } else {
        $line.Add([Segment]::new($lineSpan, $style))
      }
    }
  }

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    if ($this._lines.Count -eq 0) { return [Measurement]::new(0, 0) }

    $min = 0
    $max = 0
    foreach ($line in $this._lines) {
      # $lineMax = 0
      foreach ($seg in $line.Segments) {
        $cc = $seg.CellCount()
        if ($cc -gt $min) { $min = $cc }
      }
      $lineCc = $line.CellCount()
      if ($lineCc -gt $max) { $max = $lineCc }
    }

    return [Measurement]::new($min, [Math]::Min($max, $maxWidth))
  }

  [Segment[]] Render([RenderOptions]$options, [int]$maxWidth) {
    if ($this._lines.Count -eq 0) { return [Segment[]]@() }

    $lines = if ($options.SingleLine) { [List[SegmentLine]]::new($this._lines) } else { $this.SplitLines($maxWidth) }
    $just = if ($null -ne $options.Justification) { $options.Justification } elseif ($null -ne $this.Justification) { $this.Justification } else { [Justify]::Left }

    if ($just -ne [Justify]::Left) {
      foreach ($line in $lines) {
        [Aligner]::Align($line.Segments, $just, $maxWidth)
      }
    }

    if ($options.SingleLine) {
      $res = [List[Segment]]::new()
      foreach ($s in $lines[0].Segments) { if (!$s.IsLineBreak) { $res.Add($s) } }
      return $res.ToArray()
    }

    $outSegments = [List[Segment]]::new()
    $lineCount = @($lines).Count  # Convert to array to get proper count
    for ($i = 0; $i -lt $lineCount; $i++) {
      $outSegments.AddRange($lines[$i].Segments)
      if ($i -lt $lineCount - 1) { $outSegments.Add([Segment]::LineBreak) }
    }
    return $outSegments.ToArray()
  }

  hidden [List[SegmentLine]] SplitLines([int]$maxWidth) {
    if ($maxWidth -le 0) { return [List[SegmentLine]]::new() }

    $lines = [List[SegmentLine]]::new()
    foreach ($origLine in $this._lines) {
      $split = [Segment]::SplitLines($origLine.Segments, $maxWidth)
      $lines.AddRange($split)
    }
    return $lines
  }
}

class Text : IRenderable {
  hidden [Paragraph]$_paragraph

  Text([string]$text) {
    $this._paragraph = [Paragraph]::new($text)
  }

  Text([string]$text, [Style]$style) {
    $this._paragraph = [Paragraph]::new($text, $style)
  }

  [Nullable[Justify]] get_Justification() { return $this._paragraph.Justification }
  [void] set_Justification([Nullable[Justify]]$val) { $this._paragraph.Justification = $val }

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    return $this._paragraph.Measure($options, $maxWidth)
  }

  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    return $this._paragraph.Render($options, $maxWidth)
  }
}

class Markup : IRenderable {
  hidden [Paragraph]$_paragraph
  [Nullable[Overflow]]$Overflow
  [Nullable[Justify]]$Justify

  Markup([string]$text) {
    $this.Init($text, [Style]::Plain)
  }

  Markup([string]$text, [Style]$style) {
    $this.Init($text, $style)
  }

  hidden [void] Init([string]$text, [Style]$style) {
    $this._paragraph = [Paragraph]::new()
    foreach ($segment in [AnsiMarkup]::Parse($text, $style)) {
      $this._paragraph.Append($segment.Text, $segment.Style, $segment.Link)
    }
  }

  [Nullable[Justify]] get_Justification() { return $this._paragraph.Justification }
  [void] set_Justification([Nullable[Justify]]$val) { $this._paragraph.Justification = $val }

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    if ($null -ne $this.Overflow) { $this._paragraph.Overflow = $this.Overflow }
    if ($null -ne $this.Justify) { $this._paragraph.Justification = $this.Justify }
    return $this._paragraph.Measure($options, $maxWidth)
  }

  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    if ($null -ne $this.Overflow) { $this._paragraph.Overflow = $this.Overflow }
    if ($null -ne $this.Justify) { $this._paragraph.Justification = $this.Justify }
    return $this._paragraph.Render($options, $maxWidth)
  }
}

class Align : IRenderable {
  hidden [IRenderable]$_renderable
  [HorizontalAlignment]$Horizontal
  [Nullable[VerticalAlignment]]$Vertical
  [Nullable[int]]$Width
  [Nullable[int]]$Height

  Align([IRenderable]$renderable) {
    $this._renderable = $renderable
    $this.Horizontal = [HorizontalAlignment]::Left
  }

  Align([IRenderable]$renderable, [HorizontalAlignment]$horizontal) {
    $this._renderable = $renderable
    $this.Horizontal = $horizontal
  }

  Align([IRenderable]$renderable, [HorizontalAlignment]$horizontal, [Nullable[VerticalAlignment]]$vertical) {
    $this._renderable = $renderable
    $this.Horizontal = $horizontal
    $this.Vertical = $vertical
  }

  static [Align] Center([IRenderable]$renderable) {
    return [Align]::new($renderable, [HorizontalAlignment]::Center, $null)
  }

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    $targetWidth = if ($null -ne $this.Width) { [Math]::Min($this.Width.Value, $maxWidth) } else { $maxWidth }
    $measurement = $this._renderable.Measure($options, $targetWidth)
    return [Measurement]::new([Math]::Min($measurement.Min, $targetWidth), $targetWidth)
  }

  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    $targetWidth = if ($null -ne $this.Width) { [Math]::Min($this.Width.Value, $maxWidth) } else { $maxWidth }
    $rendered = $this._renderable.Render($options, $targetWidth)
    $lines = [Segment]::SplitLines($rendered, $targetWidth)

    $targetHeight = if ($null -ne $this.Height) { $this.Height.Value } elseif ($null -ne $options.Height) { $options.Height.Value } else { $null }
    $blank = [SegmentLine]::new([Segment[]]@([Segment]::new(" " * $targetWidth)))

    if ($null -ne $this.Vertical -and $null -ne $targetHeight) {
      switch ($this.Vertical.Value) {
        ([VerticalAlignment]::Top) {
          $diff = $targetHeight - $lines.Count
          for ($i = 0; $i -lt $diff; $i++) { $lines.Add($blank) }
        }
        ([VerticalAlignment]::Middle) {
          $top = [Math]::Floor(($targetHeight - $lines.Count) / 2)
          $bottom = $targetHeight - $top - $lines.Count
          for ($i = 0; $i -lt $top; $i++) { $lines.Insert(0, $blank) }
          for ($i = 0; $i -lt $bottom; $i++) { $lines.Add($blank) }
        }
        ([VerticalAlignment]::Bottom) {
          $diff = $targetHeight - $lines.Count
          for ($i = 0; $i -lt $diff; $i++) { $lines.Insert(0, $blank) }
        }
      }
    }

    foreach ($line in $lines) {
      [Aligner]::AlignHorizontally($line.Segments, $this.Horizontal, $targetWidth)
    }

    $outSegments = [List[Segment]]::new()
    $lineCount = @($lines).Count
    for ($i = 0; $i -lt $lineCount; $i++) {
      $outSegments.AddRange($lines[$i].Segments)
      if ($i -lt $lineCount - 1) { $outSegments.Add([Segment]::LineBreak) }
    }
    return $outSegments.ToArray()
  }
}

class Padder : IRenderable {
  hidden [IRenderable]$_child
  [Padding]$Padding
  [bool]$Expand

  Padder([IRenderable]$child) {
    $this._child = $child
    $this.Padding = [Padding]::new(1, 1, 1, 1)
    $this.Expand = $false
  }

  Padder([IRenderable]$child, [Padding]$padding) {
    $this._child = $child
    $this.Padding = $padding
    $this.Expand = $false
  }

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    $paddingWidth = if ($null -ne $this.Padding) { $this.Padding.GetWidth() } else { 0 }
    $measurement = $this._child.Measure($options, $maxWidth - $paddingWidth)
    return [Measurement]::new($measurement.Min + $paddingWidth, $measurement.Max + $paddingWidth)
  }

  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    $paddingWidth = if ($null -ne $this.Padding) { $this.Padding.GetWidth() } else { 0 }
    $childWidth = $maxWidth - $paddingWidth

    if (!$this.Expand) {
      $measurement = $this._child.Measure($options, $maxWidth - $paddingWidth)
      $childWidth = $measurement.Max
    }

    $width = $childWidth + $paddingWidth
    if ($width -gt $maxWidth) { $width = $maxWidth }

    $result = [List[Segment]]::new()

    for ($i = 0; $i -lt $this.Padding.Top; $i++) {
      $result.Add([Segment]::Padding($width))
      $result.Add([Segment]::LineBreak)
    }

    $childRendered = $this._child.Render($options, $maxWidth - $paddingWidth)
    foreach ($line in [Segment]::SplitLines($childRendered, $maxWidth - $paddingWidth)) {
      if ($this.Padding.Left -gt 0) { $result.Add([Segment]::Padding($this.Padding.Left)) }
      $result.AddRange($line.Segments)
      if ($this.Padding.Right -gt 0) { $result.Add([Segment]::Padding($this.Padding.Right)) }

      $lineWidth = $line.CellCount()
      $diff = $width - $lineWidth - $this.Padding.Left - $this.Padding.Right
      if ($diff -gt 0) { $result.Add([Segment]::Padding($diff)) }
      $result.Add([Segment]::LineBreak)
    }

    for ($i = 0; $i -lt $this.Padding.Bottom; $i++) {
      $result.Add([Segment]::Padding($width))
      $result.Add([Segment]::LineBreak)
    }

    # remove last linebreak
    if ($result.Count -gt 0 -and $result[$result.Count - 1].IsLineBreak) {
      $result.RemoveAt($result.Count - 1)
    }

    return $result.ToArray()
  }
}

class PanelHeader {
  [string]$Text
  [Justify]$Justification
  PanelHeader([string]$text, [Justify]$justification) {
    $this.Text = $text
    $this.Justification = $justification
  }
  PanelHeader([string]$text) {
    $this.Text = $text
    $this.Justification = [Justify]::Left
  }
}

class Rule : IRenderable {
  [string]$Title
  [Style]$Style
  [Nullable[Justify]]$Justification
  [BoxBorder]$Border
  [int]$TitlePadding
  [int]$TitleSpacing

  Rule() {
    $this.Style = [Style]::Plain
    $this.Border = [SquareBoxBorder]::new()
    $this.TitlePadding = 2
    $this.TitleSpacing = 1
  }

  Rule([string]$title) {
    $this.Title = $title
    $this.Style = [Style]::Plain
    $this.Border = [SquareBoxBorder]::new()
    $this.TitlePadding = 2
    $this.TitleSpacing = 1
  }

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    return [Measurement]::new($maxWidth, $maxWidth)
  }

  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    $extraLength = (2 * $this.TitlePadding) + (2 * $this.TitleSpacing)
    if ([string]::IsNullOrEmpty($this.Title) -or $maxWidth -le $extraLength) {
      $safeBorder = [BoxBorder]::GetSafeBorder($options, $this)
      $text = ""
      for ($i = 0; $i -lt $maxWidth; $i++) { $text += $safeBorder.GetPart([BoxBorderPart]::Top) }
      return [Segment[]]@([Segment]::new($text, $this.Style), [Segment]::LineBreak)
    }

    $markup = [Markup]::new($this.Title.Trim(), $this.Style)
    $opt = [RenderOptions]::new()
    $opt.SingleLine = $true
    $opt.Ansi = $options.Ansi
    $opt.ColorSystem = $options.ColorSystem
    $titleSegs = $markup.Render($opt, $maxWidth - $extraLength)

    $titleLength = [Segment]::CellCount($titleSegs)
    $safeBorder = [BoxBorder]::GetSafeBorder($options, $this)
    $borderPart = $safeBorder.GetPart([BoxBorderPart]::Top)

    $align = if ($null -ne $this.Justification) { $this.Justification.Value } else { [Justify]::Center }
    $left = $null
    $right = $null

    if ($align -eq [Justify]::Left) {
      $leftStr = ""
      for ($i = 0; $i -lt $this.TitlePadding; $i++) { $leftStr += $borderPart }
      $leftStr += " " * $this.TitleSpacing
      $left = [Segment]::new($leftStr, $this.Style)

      $rightLength = $maxWidth - $titleLength - $left.CellCount() - $this.TitleSpacing
      $rightStr = " " * $this.TitleSpacing
      for ($i = 0; $i -lt $rightLength; $i++) { $rightStr += $borderPart }
      $right = [Segment]::new($rightStr, $this.Style)
    } elseif ($align -eq [Justify]::Center) {
      $leftLength = [Math]::Floor(($maxWidth - $titleLength) / 2) - $this.TitleSpacing
      $leftStr = ""
      for ($i = 0; $i -lt $leftLength; $i++) { $leftStr += $borderPart }
      $leftStr += " " * $this.TitleSpacing
      $left = [Segment]::new($leftStr, $this.Style)

      $rightLength = $maxWidth - $titleLength - $left.CellCount() - $this.TitleSpacing
      $rightStr = " " * $this.TitleSpacing
      for ($i = 0; $i -lt $rightLength; $i++) { $rightStr += $borderPart }
      $right = [Segment]::new($rightStr, $this.Style)
    } else {
      $rightStr = " " * $this.TitleSpacing
      for ($i = 0; $i -lt $this.TitlePadding; $i++) { $rightStr += $borderPart }
      $right = [Segment]::new($rightStr, $this.Style)

      $leftLength = $maxWidth - $titleLength - $right.CellCount() - $this.TitleSpacing
      $leftStr = ""
      for ($i = 0; $i -lt $leftLength; $i++) { $leftStr += $borderPart }
      $leftStr += " " * $this.TitleSpacing
      $left = [Segment]::new($leftStr, $this.Style)
    }

    $segments = [List[Segment]]::new()
    $segments.Add($left)
    $segments.AddRange($titleSegs)
    $segments.Add($right)
    $segments.Add([Segment]::LineBreak)
    return $segments.ToArray()
  }
}

class Panel : IRenderable {
  hidden [IRenderable]$_child
  [BoxBorder]$Border
  [bool]$UseSafeBorder
  [Style]$BorderStyle
  [bool]$Expand
  [Padding]$Padding
  [PanelHeader]$Header
  [Nullable[int]]$Width
  [Nullable[int]]$Height
  [bool]$Inline

  Panel([string]$text) {
    $this.Init([Markup]::new($text))
  }

  Panel([IRenderable]$child) {
    $this.Init($child)
  }

  hidden [void] Init([IRenderable]$child) {
    $this._child = $child
    $this.Border = [SquareBoxBorder]::new()
    $this.UseSafeBorder = $true
    $this.BorderStyle = [Style]::Plain
    $this.Expand = $false
    $this.Padding = [Padding]::new(1, 0, 1, 0)
    $this.Inline = $false
  }

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    $child = [Padder]::new($this._child, $this.Padding)
    return $this.MeasureChild($options, $maxWidth, $child)
  }

  hidden [Measurement] MeasureChild([RenderOptions]$options, [int]$maxWidth, [IRenderable]$child) {
    $safeBorder = [BoxBorder]::GetSafeBorder($options, $this)
    $edgeWidth = if ($safeBorder -is [NoBoxBorder]) { 0 } else { 2 }
    $childWidth = $child.Measure($options, $maxWidth - $edgeWidth)

    if ($null -ne $this.Width) {
      $w = $this.Width.Value - $edgeWidth
      $constrained = [Math]::Min($w, $maxWidth - $edgeWidth)
      $childWidth = [Measurement]::new([Math]::Min($childWidth.Min, $constrained), $constrained)
    }

    return [Measurement]::new($childWidth.Min + $edgeWidth, $childWidth.Max + $edgeWidth)
  }

  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    $safeBorder = [BoxBorder]::GetSafeBorder($options, $this)
    $safeBorderStyle = if ($null -ne $this.BorderStyle) { $this.BorderStyle } else { [Style]::Plain }
    $showBorder = -not ($safeBorder -is [NoBoxBorder])
    $edgeWidth = if ($showBorder) { 2 } else { 0 }

    $child = [Padder]::new($this._child, $this.Padding)
    $measure = $this.MeasureChild($options, $maxWidth, $child)

    $panelWidth = if (!$this.Expand) { [Math]::Min($measure.Max, $maxWidth) } else { $maxWidth }
    $innerWidth = $panelWidth - $edgeWidth

    $targetHeight = if ($null -ne $this.Height) { $this.Height.Value - 2 } elseif ($null -ne $options.Height) { $options.Height.Value - 2 } else { $null }
    if (!$this.Expand -and $null -ne $this.Height) { $targetHeight = $this.Height.Value - 2 }

    $result = [List[Segment]]::new()

    if ($showBorder) {
      $this.AddTopBorder($result, $options, $safeBorder, $safeBorderStyle, $panelWidth)
    } elseif ($null -ne $this.Header -and -not [string]::IsNullOrEmpty($this.Header.Text)) {
      $this.AddTopBorder($result, $options, [NoBoxBorder]::new(), $safeBorderStyle, $panelWidth)
    }

    $opt = [RenderOptions]::new()
    $opt.Ansi = $options.Ansi
    $opt.ColorSystem = $options.ColorSystem
    $opt.Height = $targetHeight

    $childSegments = $child.Render($opt, $innerWidth)
    $lines = [Segment]::SplitLines($childSegments, $innerWidth)

    $lineCount = @($lines).Count
    for ($i = 0; $i -lt $lineCount; $i++) {
      $line = $lines[$i]
      $isLast = ($i -eq $lineCount - 1)
      if ($line.Segments.Count -eq 1 -and $line.Segments[0].IsWhiteSpace) { continue }

      if ($showBorder) { $result.Add([Segment]::new($safeBorder.GetPart([BoxBorderPart]::Left), $safeBorderStyle)) }

      $result.AddRange($line.Segments)
      $len = $line.CellCount()
      if ($len -lt $innerWidth) { $result.Add([Segment]::Padding($innerWidth - $len)) }

      if ($showBorder) { $result.Add([Segment]::new($safeBorder.GetPart([BoxBorderPart]::Right), $safeBorderStyle)) }

      $emitLinebreak = -not ($isLast -and !$showBorder -and !$this.Inline)
      if ($emitLinebreak) { $result.Add([Segment]::LineBreak) }
    }

    if ($showBorder) {
      $result.Add([Segment]::new($safeBorder.GetPart([BoxBorderPart]::BottomLeft), $safeBorderStyle))
      $bStr = ""
      for ($i = 0; $i -lt ($panelWidth - $edgeWidth); $i++) { $bStr += $safeBorder.GetPart([BoxBorderPart]::Bottom) }
      $result.Add([Segment]::new($bStr, $safeBorderStyle))
      $result.Add([Segment]::new($safeBorder.GetPart([BoxBorderPart]::BottomRight), $safeBorderStyle))
    }

    if (!$this.Inline) { $result.Add([Segment]::LineBreak) }

    return $result.ToArray()
  }

  hidden [void] AddTopBorder([List[Segment]]$result, [RenderOptions]$options, [BoxBorder]$border, [Style]$borderStyle, [int]$panelWidth) {
    $rule = [Rule]::new()
    $rule.Style = $borderStyle
    $rule.Border = $border
    $rule.TitlePadding = 1
    $rule.TitleSpacing = 0
    if ($null -ne $this.Header) {
      $rule.Title = $this.Header.Text
      $rule.Justification = $this.Header.Justification
    }

    $result.Add([Segment]::new($border.GetPart([BoxBorderPart]::TopLeft), $borderStyle))
    foreach ($seg in $rule.Render($options, $panelWidth - 2)) {
      if (!$seg.IsLineBreak) { $result.Add($seg) }
    }
    $result.Add([Segment]::new($border.GetPart([BoxBorderPart]::TopRight), $borderStyle))
    $result.Add([Segment]::LineBreak)
  }
}

class TextPath : IRenderable {
  hidden [string]$_path
  [Nullable[Justify]]$Justification

  TextPath([string]$path) {
    $this._path = $path
  }

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    $len = [Cell]::GetCellLength($this._path)
    $w = [Math]::Min($len, $maxWidth)
    return [Measurement]::new($w, $w)
  }

  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    $markup = [Markup]::new($this._path, [Style]::Plain)
    $markup.Justification = $this.Justification
    return $markup.Render($options, $maxWidth)
  }
}

class Calendar : IRenderable {
  [datetime]$Date
  [datetime[]]$HighlightedDates
  [Style]$HeaderStyle
  [Style]$HighlightStyle
  [Style]$TodayStyle

  Calendar([datetime]$date) {
    $this.Date = $date
    $this.Initialize()
  }

  Calendar([datetime]$date, [datetime[]]$highlightedDates) {
    $this.Date = $date
    $this.HighlightedDates = $highlightedDates
    $this.Initialize()
  }

  hidden [void] Initialize() {
    if ($null -eq $this.HighlightedDates) { $this.HighlightedDates = [datetime[]]@() }
    if ($null -eq $this.HeaderStyle) { $this.HeaderStyle = [Style]::new([Color]::Blue) }
    if ($null -eq $this.HighlightStyle) { $this.HighlightStyle = [Style]::new([Color]::Yellow) }
    if ($null -eq $this.TodayStyle) { $this.TodayStyle = [Style]::new([Color]::Green) }
  }

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    $width = [Math]::Min(20, $maxWidth)
    return [Measurement]::new($width, $width)
  }

  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    $this.Initialize()
    $renderWidth = [Math]::Min(20, [Math]::Max(1, $maxWidth))
    $segments = [System.Collections.Generic.List[Segment]]::new()
    $monthLabel = $this.Date.ToString('Y')

    $header = [Align]::Center([Markup]::new([MarkupStyleParser]::Escape($monthLabel), $this.HeaderStyle))
    $segments.AddRange($header.Render($options, $renderWidth))
    $segments.Add([Segment]::LineBreak)
    $segments.AddRange(([Text]::new('Su Mo Tu We Th Fr Sa', $this.HeaderStyle)).Render($options, $renderWidth))
    $segments.Add([Segment]::LineBreak)

    $first = [datetime]::new($this.Date.Year, $this.Date.Month, 1)
    $daysInMonth = [datetime]::DaysInMonth($this.Date.Year, $this.Date.Month)
    $today = [datetime]::Today
    $highlightLookup = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($highlightDate in $this.HighlightedDates) {
      [void]$highlightLookup.Add($highlightDate.Date.ToString('yyyy-MM-dd'))
    }

    $weekSegments = [System.Collections.Generic.List[Segment]]::new()
    $offset = [int]$first.DayOfWeek
    for ($i = 0; $i -lt $offset; $i++) {
      $weekSegments.Add([Segment]::new('   ', [Style]::Plain))
    }

    for ($day = 1; $day -le $daysInMonth; $day++) {
      $currentDate = [datetime]::new($this.Date.Year, $this.Date.Month, $day)
      $dateKey = $currentDate.ToString('yyyy-MM-dd')
      $style = [Style]::Plain
      if ($highlightLookup.Contains($dateKey)) {
        $style = $this.HighlightStyle
      } elseif ($currentDate.Date -eq $today.Date) {
        $style = $this.TodayStyle
      }

      $weekSegments.Add([Segment]::new(('{0,2}' -f $day), $style))
      if ((($offset + $day) % 7) -ne 0 -and $day -lt $daysInMonth) {
        $weekSegments.Add([Segment]::new(' ', [Style]::Plain))
      }

      if ((($offset + $day) % 7) -eq 0 -or $day -eq $daysInMonth) {
        $segments.AddRange($weekSegments)
        if ($day -lt $daysInMonth) {
          $segments.Add([Segment]::LineBreak)
        }
        $weekSegments = [System.Collections.Generic.List[Segment]]::new()
      }
    }

    return $segments.ToArray()
  }
}
