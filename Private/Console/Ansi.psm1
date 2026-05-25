using namespace System
using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Text

using module .\Enums.psm1
using module .\Colors.psm1
using module .\Internal.psm1
using module .\Rendering.psm1

class AnsiCapabilities {
  [ColorSystem]$ColorSystem
  [bool]$Ansi
  [bool]$Links
  [bool]$AlternateBuffer

  AnsiCapabilities() {
    $this.ColorSystem = [ColorSystem]::NoColors
    $this.Ansi = $false
    $this.Links = $false
    $this.AlternateBuffer = $false
  }
}

class AnsiCodeBuilder {
  static [byte[]] Build([Decoration]$decoration) {
    $codes = [List[byte]]::new()
    if (($decoration -band [Decoration]::Bold) -ne 0) { $codes.Add(1) }
    if (($decoration -band [Decoration]::Dim) -ne 0) { $codes.Add(2) }
    if (($decoration -band [Decoration]::Italic) -ne 0) { $codes.Add(3) }
    if (($decoration -band [Decoration]::Underline) -ne 0) { $codes.Add(4) }
    if (($decoration -band [Decoration]::SlowBlink) -ne 0) { $codes.Add(5) }
    if (($decoration -band [Decoration]::RapidBlink) -ne 0) { $codes.Add(6) }
    if (($decoration -band [Decoration]::Invert) -ne 0) { $codes.Add(7) }
    if (($decoration -band [Decoration]::Conceal) -ne 0) { $codes.Add(8) }
    if (($decoration -band [Decoration]::Strikethrough) -ne 0) { $codes.Add(9) }
    return $codes.ToArray()
  }

  static [byte[]] Build([ColorSystem]$system, [object]$color, [bool]$foreground) {
    if ($null -eq $color -or ([Color]$color).IsDefault) { return [byte[]]@() }
    $c = [Color]$color
    switch ($system) {
      ([ColorSystem]::NoColors) { return [byte[]]@() }
      ([ColorSystem]::TrueColor) {
        if ($null -ne $c.Number) { return [AnsiCodeBuilder]::GetEightBit($c, $foreground) }
        $mod = $foreground ? 38 : 48
        return [byte[]]@($mod, 2, $c.R, $c.G, $c.B)
      }
      ([ColorSystem]::EightBit) { return [AnsiCodeBuilder]::GetEightBit($c, $foreground) }
      ([ColorSystem]::Standard) { return [AnsiCodeBuilder]::GetFourBit($c, $foreground) }
      ([ColorSystem]::Legacy) { return [AnsiCodeBuilder]::GetThreeBit($c, $foreground) }
      default { return [byte[]]@() }
    }
    return [byte[]]@()
  }

  static hidden [byte[]] GetThreeBit([Color]$color, [bool]$foreground) {
    $num = $color.Number
    if ($null -eq $num -or $num -ge 8) { $num = $color.ExactOrClosest([ColorSystem]::Legacy).Number }
    $mod = $foreground ? 30 : 40
    return [byte[]]@([byte]($num + $mod))
  }

  static hidden [byte[]] GetFourBit([Color]$color, [bool]$foreground) {
    $num = $color.Number
    if ($null -eq $num -or $num -ge 16) { $num = $color.ExactOrClosest([ColorSystem]::Standard).Number }
    $mod = $num -lt 8 ? ($foreground ? 30 : 40) : ($foreground ? 82 : 92)
    return [byte[]]@([byte]($num + $mod))
  }

  static hidden [byte[]] GetEightBit([Color]$color, [bool]$foreground) {
    $num = $color.Number
    if ($null -eq $num) { $num = $color.ExactOrClosest([ColorSystem]::EightBit).Number }
    $mod = $foreground ? [byte]38 : [byte]48
    return [byte[]]@($mod, 5, [byte]$num)
  }

  static [string] GetAnsi([Style]$style, [ColorSystem]$system) {
    $codes = [List[byte]]::new()
    $codes.AddRange([AnsiCodeBuilder]::Build($style.Decoration))
    $codes.AddRange([AnsiCodeBuilder]::Build($system, $style.Foreground, $true))
    $codes.AddRange([AnsiCodeBuilder]::Build($system, $style.Background, $false))
    return [string]::Join(';', $codes)
  }
}

class AnsiWriter {
  hidden [ConsoleWriter]$_output
  hidden [int]$_linkCount
  [AnsiCapabilities]$Capabilities

  AnsiWriter([ConsoleWriter]$output) {
    $this._output = $output
    $this.Capabilities = [AnsiCapabilities]::new()
    $this.Capabilities.Ansi = $true
    $this.Capabilities.ColorSystem = [ColorSystem]::TrueColor
    $this.Capabilities.Links = $true
    $this._linkCount = 0
  }

  [ConsoleWriter] GetOutput() {
    return $this._output
  }

  [void] Write([string]$text) {
    $this._output.Write($text)
  }

  [void] WriteLine() {
    $this._output.WriteLine()
  }

  [void] WriteLine([string]$text) {
    $this._output.WriteLine($text)
  }

  [void] Write([string]$text, [Style]$style) {
    $this.Write($text, $style, $null)
  }

  [void] Write([string]$text, [Style]$style, [AnsiLink]$link) {
    $shouldClose = $false
    if ($this.Capabilities.Ansi) {
      if ($null -ne $link) {
        $this.BeginLink($link)
      }

      $codes = [List[byte]]::new()
      $codes.AddRange([AnsiCodeBuilder]::Build($style.Decoration))
      $codes.AddRange([AnsiCodeBuilder]::Build($this.Capabilities.ColorSystem, $style.Foreground, $true))
      $codes.AddRange([AnsiCodeBuilder]::Build($this.Capabilities.ColorSystem, $style.Background, $false))

      if ($codes.Count -gt 0) {
        $this.WriteCsi([string]::Join(';', $codes) + 'm')
        $shouldClose = $true
      }
    }

    $this.Write($text)

    if ($shouldClose) {
      $this.WriteCsi('0m')
    }

    if ($null -ne $link) {
      $this.EndLink()
    }
  }

  [void] WriteLine([string]$text, [Style]$style) {
    $this.Write($text, $style, $null)
    $this.WriteLine()
  }

  [void] Style([Style]$style) {
    if (!$this.Capabilities.Ansi) { return }
    $codes = [List[byte]]::new()
    $codes.AddRange([AnsiCodeBuilder]::Build($style.Decoration))
    $codes.AddRange([AnsiCodeBuilder]::Build($this.Capabilities.ColorSystem, $style.Foreground, $true))
    $codes.AddRange([AnsiCodeBuilder]::Build($this.Capabilities.ColorSystem, $style.Background, $false))
    if ($codes.Count -gt 0) {
      $this.WriteCsi([string]::Join(';', $codes) + 'm')
    }
  }

  [void] ResetStyle() {
    if ($this.Capabilities.Ansi) {
      $this.WriteCsi('0m')
      $this.EndLink()
    }
  }

  [void] BeginLink([AnsiLink]$link) {
    if ($null -eq $link) { return }
    if ($this.Capabilities.Ansi -and $this.Capabilities.Links) {
      $this._linkCount++
      $suffix = if ($link.Id.HasValue) { "id=$($link.Id);" } else { '' }
      $this.Write("`e]8;${suffix}$($link.Url)`e\")
    }
  }

  [void] EndLink() {
    if ($this.Capabilities.Ansi -and $this.Capabilities.Links -and $this._linkCount -gt 0) {
      $this._linkCount--
      $this.Write("`e]8;;`e\")
    }
  }

  [void] CursorUp([int]$steps) {
    if ($steps -gt 0) { $this.WriteCsi("${steps}A") }
  }

  [void] CursorDown([int]$steps) {
    if ($steps -gt 0) { $this.WriteCsi("${steps}B") }
  }

  [void] CursorHorizontalAbsolute([int]$column) {
    $this.WriteCsi("${column}G")
  }

  [void] EraseInLine([int]$mode = 0) {
    # 0 = cursor to end, 1 = beginning to cursor, 2 = whole line
    $this.WriteCsi("${mode}K")
  }

  [void] EraseInDisplay([int]$mode = 0) {
    # 0 = cursor to end, 1 = beginning to cursor, 2 = whole display, 3 = whole display + scrollback
    $this.WriteCsi("${mode}J")
  }

  hidden [void] WriteCsi([string]$parameters) {
    if ($this.Capabilities.Ansi) {
      $this.Write("`e[" + $parameters)
    }
  }
}

class AnsiLink {
  [Nullable[int]]$Id
  [string]$Url
  AnsiLink([string]$url) {
    $this.Url = $url
    $this.Id = [Random]::new().Next(0, [int]::MaxValue)
  }
}

class AnsiMarkupSegment {
  [string]$Text
  [Style]$Style
  [AnsiLink]$Link
  AnsiMarkupSegment([string]$text, [Style]$style, [AnsiLink]$link) {
    $this.Text = $text
    $this.Style = $style
    $this.Link = $link
  }
}

class AnsiMarkup {
  hidden [AnsiWriter]$_writer

  AnsiMarkup([AnsiWriter]$writer) {
    $this._writer = $writer
  }

  [void] Write([string]$markup) {
    $this.Write($markup, [Style]::Plain)
  }

  [void] Write([string]$markup, [Style]$style) {
    foreach ($segment in [AnsiMarkup]::Parse($markup, $style)) {
      $this._writer.Write($segment.Text, $segment.Style, $segment.Link)
    }
  }

  [void] WriteLine([string]$markup) {
    $this.Write($markup, [Style]::Plain)
    $this._writer.WriteLine()
  }

  static [List[AnsiMarkupSegment]] Parse([string]$markup, [Style]$style) {
    $result = [List[AnsiMarkupSegment]]::new()
    if ($null -eq $style) { $style = [Style]::Plain }
    foreach ($segment in [MarkupStyleParser]::ParseMarkup($markup, $style)) {
      $link = if ([string]::IsNullOrWhiteSpace($segment.Link)) { $null } else { [AnsiLink]::new($segment.Link) }
      $result.Add([AnsiMarkupSegment]::new($segment.Text, $segment.Style, $link))
    }
    return $result
  }

  static [Style] ParseTag([string]$tag) {
    return [MarkupStyleParser]::ParseStyle($tag)
  }

  static [string] Escape([string]$markup) {
    return [MarkupStyleParser]::Escape($markup)
  }

  static [string] Remove([string]$markup) {
    return [MarkupStyleParser]::RemoveMarkup($markup)
  }

  static [string] Highlight([string]$markup, [string]$query, [Style]$style) {
    if ([string]::IsNullOrEmpty($query)) {
      return $markup
    }

    $plainText = [AnsiMarkup]::Remove($markup)
    $index = $plainText.IndexOf($query, [StringComparison]::OrdinalIgnoreCase)
    if ($index -lt 0) {
      return $markup
    }

    $prefix = $plainText.Substring(0, $index)
    $match = $plainText.Substring($index, $query.Length)
    $suffix = $plainText.Substring($index + $query.Length)
    $markupStyle = if ($null -ne $style) { $style.ToMarkup() } else { [Style]::Plain.ToMarkup() }
    if ([string]::IsNullOrWhiteSpace($markupStyle)) {
      return [AnsiMarkup]::Escape($plainText)
    }

    return "{0}[{1}]{2}[/]{3}" -f [AnsiMarkup]::Escape($prefix), $markupStyle, [AnsiMarkup]::Escape($match), [AnsiMarkup]::Escape($suffix)
  }
}
