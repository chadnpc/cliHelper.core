using namespace System
using namespace System.Collections.Generic

using module .\Enums.psm1

class BoxBorder {
  [string] GetPart([BoxBorderPart]$part) {
    return ""
  }

  [BoxBorder] GetSafeBorder([bool]$safe) {
    if ($safe) { return [AsciiBoxBorder]::new() }
    return $this
  }

  static [BoxBorder] GetSafeBorder([RenderOptions]$options, [object]$borderable) {
    if ($null -eq $borderable -or -not ('Border' -in $borderable.PSObject.Properties.Name)) { return [NoBoxBorder]::new() }
    $border = $borderable.Border
    if ($null -eq $border) { return [NoBoxBorder]::new() }
    if ($borderable.PSObject.Properties.Name -contains 'UseSafeBorder' -and !$borderable.UseSafeBorder) { return $border }
    if (!$options.Unicode) { return $border.GetSafeBorder($true) }
    return $border
  }
}

class NoBoxBorder : BoxBorder {
  [string] GetPart([BoxBorderPart]$part) { return "" }
}

class AsciiBoxBorder : BoxBorder {
  [string] GetPart([BoxBorderPart]$part) {
    switch ($part) {
      ([BoxBorderPart]::HeaderTopLeft) { return "+" }
      ([BoxBorderPart]::HeaderTop) { return "-" }
      ([BoxBorderPart]::HeaderTopRight) { return "+" }
      ([BoxBorderPart]::HeaderRight) { return "|" }
      ([BoxBorderPart]::HeaderBottomRight) { return "+" }
      ([BoxBorderPart]::HeaderBottom) { return "-" }
      ([BoxBorderPart]::HeaderBottomLeft) { return "+" }
      ([BoxBorderPart]::HeaderLeft) { return "|" }
      ([BoxBorderPart]::TopLeft) { return "+" }
      ([BoxBorderPart]::Top) { return "-" }
      ([BoxBorderPart]::TopRight) { return "+" }
      ([BoxBorderPart]::Right) { return "|" }
      ([BoxBorderPart]::BottomRight) { return "+" }
      ([BoxBorderPart]::Bottom) { return "-" }
      ([BoxBorderPart]::BottomLeft) { return "+" }
      ([BoxBorderPart]::Left) { return "|" }
      default { return "" }
    }
    return ""
  }
}

class SquareBoxBorder : BoxBorder {
  [string] GetPart([BoxBorderPart]$part) {
    switch ($part) {
      ([BoxBorderPart]::HeaderTopLeft) { return "┌" }
      ([BoxBorderPart]::HeaderTop) { return "─" }
      ([BoxBorderPart]::HeaderTopRight) { return "┐" }
      ([BoxBorderPart]::HeaderRight) { return "│" }
      ([BoxBorderPart]::HeaderBottomRight) { return "┤" }
      ([BoxBorderPart]::HeaderBottom) { return "─" }
      ([BoxBorderPart]::HeaderBottomLeft) { return "├" }
      ([BoxBorderPart]::HeaderLeft) { return "│" }
      ([BoxBorderPart]::TopLeft) { return "┌" }
      ([BoxBorderPart]::Top) { return "─" }
      ([BoxBorderPart]::TopRight) { return "┐" }
      ([BoxBorderPart]::Right) { return "│" }
      ([BoxBorderPart]::BottomRight) { return "┘" }
      ([BoxBorderPart]::Bottom) { return "─" }
      ([BoxBorderPart]::BottomLeft) { return "└" }
      ([BoxBorderPart]::Left) { return "│" }
      default { return "" }
    }
    return ""
  }
}

class RoundedBoxBorder : BoxBorder {
  [string] GetPart([BoxBorderPart]$part) {
    switch ($part) {
      ([BoxBorderPart]::HeaderTopLeft) { return "╭" }
      ([BoxBorderPart]::HeaderTop) { return "─" }
      ([BoxBorderPart]::HeaderTopRight) { return "╮" }
      ([BoxBorderPart]::HeaderRight) { return "│" }
      ([BoxBorderPart]::HeaderBottomRight) { return "┤" }
      ([BoxBorderPart]::HeaderBottom) { return "─" }
      ([BoxBorderPart]::HeaderBottomLeft) { return "├" }
      ([BoxBorderPart]::HeaderLeft) { return "│" }
      ([BoxBorderPart]::TopLeft) { return "╭" }
      ([BoxBorderPart]::Top) { return "─" }
      ([BoxBorderPart]::TopRight) { return "╮" }
      ([BoxBorderPart]::Right) { return "│" }
      ([BoxBorderPart]::BottomRight) { return "╯" }
      ([BoxBorderPart]::Bottom) { return "─" }
      ([BoxBorderPart]::BottomLeft) { return "╰" }
      ([BoxBorderPart]::Left) { return "│" }
      default { return "" }
    }
    return ""
  }
}

class HeavyBoxBorder : BoxBorder {
  [string] GetPart([BoxBorderPart]$part) {
    switch ($part) {
      ([BoxBorderPart]::HeaderTopLeft) { return "┏" }
      ([BoxBorderPart]::HeaderTop) { return "━" }
      ([BoxBorderPart]::HeaderTopRight) { return "┓" }
      ([BoxBorderPart]::HeaderRight) { return "┃" }
      ([BoxBorderPart]::HeaderBottomRight) { return "┫" }
      ([BoxBorderPart]::HeaderBottom) { return "━" }
      ([BoxBorderPart]::HeaderBottomLeft) { return "┣" }
      ([BoxBorderPart]::HeaderLeft) { return "┃" }
      ([BoxBorderPart]::TopLeft) { return "┏" }
      ([BoxBorderPart]::Top) { return "━" }
      ([BoxBorderPart]::TopRight) { return "┓" }
      ([BoxBorderPart]::Right) { return "┃" }
      ([BoxBorderPart]::BottomRight) { return "┛" }
      ([BoxBorderPart]::Bottom) { return "━" }
      ([BoxBorderPart]::BottomLeft) { return "┗" }
      ([BoxBorderPart]::Left) { return "┃" }
      default { return "" }
    }
    return ""
  }
}

class DoubleBoxBorder : BoxBorder {
  [string] GetPart([BoxBorderPart]$part) {
    switch ($part) {
      ([BoxBorderPart]::HeaderTopLeft) { return "╔" }
      ([BoxBorderPart]::HeaderTop) { return "═" }
      ([BoxBorderPart]::HeaderTopRight) { return "╗" }
      ([BoxBorderPart]::HeaderRight) { return "║" }
      ([BoxBorderPart]::HeaderBottomRight) { return "╣" }
      ([BoxBorderPart]::HeaderBottom) { return "═" }
      ([BoxBorderPart]::HeaderBottomLeft) { return "╠" }
      ([BoxBorderPart]::HeaderLeft) { return "║" }
      ([BoxBorderPart]::TopLeft) { return "╔" }
      ([BoxBorderPart]::Top) { return "═" }
      ([BoxBorderPart]::TopRight) { return "╗" }
      ([BoxBorderPart]::Right) { return "║" }
      ([BoxBorderPart]::BottomRight) { return "╝" }
      ([BoxBorderPart]::Bottom) { return "═" }
      ([BoxBorderPart]::BottomLeft) { return "╚" }
      ([BoxBorderPart]::Left) { return "║" }
      default { return "" }
    }
    return ""
  }
}
