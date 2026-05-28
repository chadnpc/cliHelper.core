using namespace System
using namespace System.Globalization
using namespace System.Collections.Generic

using module ..\Enums.psm1
using module ..\Abstracts.psm1

class ColorTable {
  static hidden [byte[]] $RgbData = @(0, 0, 0, 128, 0, 0, 0, 128, 0, 128, 128, 0, 0, 0, 128, 128, 0, 128, 0, 128, 128, 192, 192, 192, 128, 128, 128, 255, 0, 0, 0, 255, 0, 255, 255, 0, 0, 0, 255, 255, 0, 255, 0, 255, 255, 255, 255, 255, 0, 0, 0, 0, 0, 95, 0, 0, 135, 0, 0, 175, 0, 0, 215, 0, 0, 255, 0, 95, 0, 0, 95, 95, 0, 95, 135, 0, 95, 175, 0, 95, 215, 0, 95, 255, 0, 135, 0, 0, 135, 95, 0, 135, 135, 0, 135, 175, 0, 135, 215, 0, 135, 255, 0, 175, 0, 0, 175, 95, 0, 175, 135, 0, 175, 175, 0, 175, 215, 0, 175, 255, 0, 215, 0, 0, 215, 95, 0, 215, 135, 0, 215, 175, 0, 215, 215, 0, 215, 255, 0, 255, 0, 0, 255, 95, 0, 255, 135, 0, 255, 175, 0, 255, 215, 0, 255, 255, 95, 0, 0, 95, 0, 95, 95, 0, 135, 95, 0, 175, 95, 0, 215, 95, 0, 255, 95, 95, 0, 95, 95, 95, 95, 95, 135, 95, 95, 175, 95, 95, 215, 95, 95, 255, 95, 135, 0, 95, 135, 95, 95, 135, 135, 95, 135, 175, 95, 135, 215, 95, 135, 255, 95, 175, 0, 95, 175, 95, 95, 175, 135, 95, 175, 175, 95, 175, 215, 95, 175, 255, 95, 215, 0, 95, 215, 95, 95, 215, 135, 95, 215, 175, 95, 215, 215, 95, 215, 255, 95, 255, 0, 95, 255, 95, 95, 255, 135, 95, 255, 175, 95, 255, 215, 95, 255, 255, 135, 0, 0, 135, 0, 95, 135, 0, 135, 135, 0, 175, 135, 0, 215, 135, 0, 255, 135, 95, 0, 135, 95, 95, 135, 95, 135, 135, 95, 175, 135, 95, 215, 135, 95, 255, 135, 135, 0, 135, 135, 95, 135, 135, 135, 135, 135, 175, 135, 135, 215, 135, 135, 255, 135, 175, 0, 135, 175, 95, 135, 175, 135, 135, 175, 175, 135, 175, 215, 135, 175, 255, 135, 215, 0, 135, 215, 95, 135, 215, 135, 135, 215, 175, 135, 215, 215, 135, 215, 255, 135, 255, 0, 135, 255, 95, 135, 255, 135, 135, 255, 175, 135, 255, 215, 135, 255, 255, 175, 0, 0, 175, 0, 95, 175, 0, 135, 175, 0, 175, 175, 0, 215, 175, 0, 255, 175, 95, 0, 175, 95, 95, 175, 95, 135, 175, 95, 175, 175, 95, 215, 175, 95, 255, 175, 135, 0, 175, 135, 95, 175, 135, 135, 175, 135, 175, 175, 135, 215, 175, 135, 255, 175, 175, 0, 175, 175, 95, 175, 175, 135, 175, 175, 175, 175, 175, 215, 175, 175, 255, 175, 215, 0, 175, 215, 95, 175, 215, 135, 175, 215, 175, 175, 215, 215, 175, 215, 255, 175, 255, 0, 175, 255, 95, 175, 255, 135, 175, 255, 175, 175, 255, 215, 175, 255, 255, 215, 0, 0, 215, 0, 95, 215, 0, 135, 215, 0, 175, 215, 0, 215, 215, 0, 255, 215, 95, 0, 215, 95, 95, 215, 95, 135, 215, 95, 175, 215, 95, 215, 215, 95, 255, 215, 135, 0, 215, 135, 95, 215, 135, 135, 215, 135, 175, 215, 135, 215, 215, 135, 255, 215, 175, 0, 215, 175, 95, 215, 175, 135, 215, 175, 175, 215, 175, 215, 215, 175, 255, 215, 215, 0, 215, 215, 95, 215, 215, 135, 215, 215, 175, 215, 215, 215, 215, 215, 255, 215, 255, 0, 215, 255, 95, 215, 255, 135, 215, 255, 175, 215, 255, 215, 215, 255, 255, 255, 0, 0, 255, 0, 95, 255, 0, 135, 255, 0, 175, 255, 0, 215, 255, 0, 255, 255, 95, 0, 255, 95, 95, 255, 95, 135, 255, 95, 175, 255, 95, 215, 255, 95, 255, 255, 135, 0, 255, 135, 95, 255, 135, 135, 255, 135, 175, 255, 135, 215, 255, 135, 255, 255, 175, 0, 255, 175, 95, 255, 175, 135, 255, 175, 175, 255, 175, 215, 255, 175, 255, 255, 215, 0, 255, 215, 95, 255, 215, 135, 255, 215, 175, 255, 215, 215, 255, 215, 255, 255, 255, 0, 255, 255, 95, 255, 255, 135, 255, 255, 175, 255, 255, 215, 255, 255, 255, 8, 8, 8, 18, 18, 18, 28, 28, 28, 38, 38, 38, 48, 48, 48, 58, 58, 58, 68, 68, 68, 78, 78, 78, 88, 88, 88, 98, 98, 98, 108, 108, 108, 118, 118, 118, 128, 128, 128, 138, 138, 138, 148, 148, 148, 158, 158, 158, 168, 168, 168, 178, 178, 178, 188, 188, 188, 198, 198, 198, 208, 208, 208, 218, 218, 218, 228, 228, 228, 238, 238, 238)
  static hidden [string[]] $Names = @('Black', 'Maroon', 'Green', 'Olive', 'Navy', 'Purple', 'Teal', 'Silver', 'Grey', 'Red', 'Lime', 'Yellow', 'Blue', 'Fuchsia', 'Aqua', 'White', 'Grey0', 'NavyBlue', 'DarkBlue', 'Blue3', 'Blue3', 'Blue1', 'DarkGreen', 'DeepSkyBlue4', 'DeepSkyBlue4', 'DeepSkyBlue4', 'DodgerBlue3', 'DodgerBlue2', 'Green4', 'SpringGreen4', 'Turquoise4', 'DeepSkyBlue3', 'DeepSkyBlue3', 'DodgerBlue1', 'Green3', 'SpringGreen3', 'DarkCyan', 'LightSeaGreen', 'DeepSkyBlue2', 'DeepSkyBlue1', 'Green3', 'SpringGreen3', 'SpringGreen2', 'Cyan3', 'DarkTurquoise', 'Turquoise2', 'Green1', 'SpringGreen2', 'SpringGreen1', 'MediumSpringGreen', 'Cyan2', 'Cyan1', 'DarkRed', 'DeepPink4', 'Purple4', 'Purple4', 'Purple3', 'BlueViolet', 'Orange4', 'Grey37', 'MediumPurple4', 'SlateBlue3', 'SlateBlue3', 'RoyalBlue1', 'Chartreuse4', 'DarkSeaGreen4', 'PaleTurquoise4', 'SteelBlue', 'SteelBlue3', 'CornflowerBlue', 'Chartreuse3', 'DarkSeaGreen4', 'CadetBlue', 'CadetBlue', 'SkyBlue3', 'SteelBlue1', 'Chartreuse3', 'PaleGreen3', 'SeaGreen3', 'Aquamarine3', 'MediumTurquoise', 'SteelBlue1', 'Chartreuse2', 'SeaGreen2', 'SeaGreen1', 'SeaGreen1', 'Aquamarine1', 'DarkSlateGray2', 'DarkRed', 'DeepPink4', 'DarkMagenta', 'DarkMagenta', 'DarkViolet', 'Purple', 'Orange4', 'LightPink4', 'Plum4', 'MediumPurple3', 'MediumPurple3', 'SlateBlue1', 'Yellow4', 'Wheat4', 'Grey53', 'LightSlateGrey', 'MediumPurple', 'LightSlateBlue', 'Yellow4', 'DarkOliveGreen3', 'DarkSeaGreen', 'LightSkyBlue3', 'LightSkyBlue3', 'SkyBlue2', 'Chartreuse2', 'DarkOliveGreen3', 'PaleGreen3', 'DarkSeaGreen3', 'DarkSlateGray3', 'SkyBlue1', 'Chartreuse1', 'LightGreen', 'LightGreen', 'PaleGreen1', 'Aquamarine1', 'DarkSlateGray1', 'Red3', 'DeepPink4', 'MediumVioletRed', 'Magenta3', 'DarkViolet', 'Purple', 'DarkOrange3', 'IndianRed', 'HotPink3', 'MediumOrchid3', 'MediumOrchid', 'MediumPurple2', 'DarkGoldenrod', 'LightSalmon3', 'RosyBrown', 'Grey63', 'MediumPurple2', 'MediumPurple1', 'Gold3', 'DarkKhaki', 'NavajoWhite3', 'Grey69', 'LightSteelBlue3', 'LightSteelBlue', 'Yellow3', 'DarkOliveGreen3', 'DarkSeaGreen3', 'DarkSeaGreen2', 'LightCyan3', 'LightSkyBlue1', 'GreenYellow', 'DarkOliveGreen2', 'PaleGreen1', 'DarkSeaGreen2', 'DarkSeaGreen1', 'PaleTurquoise1', 'Red3', 'DeepPink3', 'DeepPink3', 'Magenta3', 'Magenta3', 'Magenta2', 'DarkOrange3', 'IndianRed', 'HotPink3', 'HotPink2', 'Orchid', 'MediumOrchid1', 'Orange3', 'LightSalmon3', 'LightPink3', 'Pink3', 'Plum3', 'Violet', 'Gold3', 'LightGoldenrod3', 'Tan', 'MistyRose3', 'Thistle3', 'Plum2', 'Yellow3', 'Khaki3', 'LightGoldenrod2', 'LightYellow3', 'Grey84', 'LightSteelBlue1', 'Yellow2', 'DarkOliveGreen1', 'DarkOliveGreen1', 'DarkSeaGreen1', 'Honeydew2', 'LightCyan1', 'Red1', 'DeepPink2', 'DeepPink1', 'DeepPink1', 'Magenta2', 'Magenta1', 'OrangeRed1', 'IndianRed1', 'IndianRed1', 'HotPink', 'HotPink', 'MediumOrchid1', 'DarkOrange', 'Salmon1', 'LightCoral', 'PaleVioletRed1', 'Orchid2', 'Orchid1', 'Orange1', 'SandyBrown', 'LightSalmon1', 'LightPink1', 'Pink1', 'Plum1', 'Gold1', 'LightGoldenrod2', 'LightGoldenrod2', 'NavajoWhite1', 'MistyRose1', 'Thistle1', 'Yellow1', 'LightGoldenrod1', 'Khaki1', 'Wheat1', 'Cornsilk1', 'Grey100', 'Grey3', 'Grey7', 'Grey11', 'Grey15', 'Grey19', 'Grey23', 'Grey27', 'Grey30', 'Grey35', 'Grey39', 'Grey42', 'Grey46', 'Grey50', 'Grey54', 'Grey58', 'Grey62', 'Grey66', 'Grey70', 'Grey74', 'Grey78', 'Grey82', 'Grey85', 'Grey89', 'Grey93')
  static hidden [System.Collections.Generic.Dictionary[string, int]] $NameToNumber

  static [Color] GetColor([int]$number) {
    if ($number -lt 0 -or $number -gt 255) { throw "Color number must be between 0 and 255" }
    $offset = $number * 3
    return [Color]::new([ColorTable]::RgbData[$offset], [ColorTable]::RgbData[$offset + 1], [ColorTable]::RgbData[$offset + 2], $number, $false)
  }

  static [Color] GetColor([string]$name) {
    if ($null -eq [ColorTable]::NameToNumber) {
      $dict = [System.Collections.Generic.Dictionary[string, int]]::new([StringComparer]::OrdinalIgnoreCase)
      for ($i = 0; $i -lt [ColorTable]::Names.Count; $i++) {
        if (!$dict.ContainsKey([ColorTable]::Names[$i])) {
          $dict.Add([ColorTable]::Names[$i], $i)
        }
      }
      [ColorTable]::NameToNumber = $dict
    }
    if ([ColorTable]::NameToNumber.ContainsKey($name)) {
      return [ColorTable]::GetColor([ColorTable]::NameToNumber[$name])
    }
    return $null
  }

  static [string] GetName([int]$number) {
    if ($number -ge 0 -and $number -lt [ColorTable]::Names.Count) {
      return [ColorTable]::Names[$number]
    }
    return $null
  }
}

class Color {
  [byte]$R
  [byte]$G
  [byte]$B
  [Nullable[byte]]$Number
  [bool]$IsDefault

  static [Color] $Default

  static Color() {
    [Color]::Default = [Color]::new(0, 0, 0, $null, $true)
  }

  Color() {}

  Color([byte]$r, [byte]$g, [byte]$b) {
    $this.R = $r
    $this.G = $g
    $this.B = $b
    $this.IsDefault = $false
    $this.Number = $null
  }

  Color([byte]$r, [byte]$g, [byte]$b, [Nullable[byte]]$number, [bool]$isDefault) {
    $this.R = $r
    $this.G = $g
    $this.B = $b
    $this.Number = $number
    $this.IsDefault = $isDefault
  }

  Color([string]$colorOrHex) {
    if ([string]::IsNullOrWhiteSpace($colorOrHex)) {
      $this.IsDefault = $true
      return
    }
    $c = if ($colorOrHex.StartsWith("#")) { [Color]::FromHex($colorOrHex) } else { [Color]::FromName($colorOrHex) }
    if ($null -eq $c) { throw "Unknown color: '$colorOrHex'" }
    $this.R = $c.R
    $this.G = $c.G
    $this.B = $c.B
    $this.Number = $c.Number
    $this.IsDefault = $c.IsDefault
  }

  [string] ToHex() {
    return "{0:X2}{1:X2}{2:X2}" -f $this.R, $this.G, $this.B
  }

  [string] ToMarkup() {
    if ($this.IsDefault) { return "default" }
    if ($null -ne $this.Number) {
      $name = [ColorTable]::GetName($this.Number)
      if (-not [string]::IsNullOrWhiteSpace($name)) { return $name }
    }
    return "#" + $this.ToHex()
  }

  [string] ToString() {
    return $this.ToMarkup()
  }

  [bool] Equals([object]$other) {
    if ($null -eq $other -or $other.GetType().Name -ne 'Color') { return $false }
    $otherColor = [Color]$other
    if ($this.IsDefault -and $otherColor.IsDefault) { return $true }
    return $this.IsDefault -eq $otherColor.IsDefault -and $this.R -eq $otherColor.R -and $this.G -eq $otherColor.G -and $this.B -eq $otherColor.B
  }

  [Color] ExactOrClosest([ColorSystem]$system) {
    if ($this.IsDefault) {
      return [Color]::Default
    }

    $max = switch ($system) {
      ([ColorSystem]::Legacy) { 7 }
      ([ColorSystem]::Standard) { 15 }
      ([ColorSystem]::EightBit) { 255 }
      ([ColorSystem]::TrueColor) { return $this }
      default { return [Color]::Default }
    }

    if ($null -ne $this.Number -and $this.Number -le $max) {
      return $this
    }

    $closest = [ColorTable]::GetColor(0)
    $bestDistance = [double]::PositiveInfinity
    for ($index = 0; $index -le $max; $index++) {
      $candidate = [ColorTable]::GetColor($index)
      $dr = [double]$this.R - [double]$candidate.R
      $dg = [double]$this.G - [double]$candidate.G
      $db = [double]$this.B - [double]$candidate.B
      $distance = ($dr * $dr) + ($dg * $dg) + ($db * $db)
      if ($distance -lt $bestDistance) {
        $bestDistance = $distance
        $closest = $candidate
      }
    }

    return $closest
  }

  static [Color] FromInt32([int]$number) {
    return [ColorTable]::GetColor($number)
  }

  static [Color] FromHex([string]$hex) {
    if ($hex.StartsWith("#")) { $hex = $hex.Substring(1) }
    if ($hex.Length -eq 3) {
      $hex = "$($hex[0])$($hex[0])$($hex[1])$($hex[1])$($hex[2])$($hex[2])"
    }
    $_r = [byte]::Parse($hex.Substring(0, 2), [NumberStyles]::HexNumber)
    $_g = [byte]::Parse($hex.Substring(2, 2), [NumberStyles]::HexNumber)
    $_b = [byte]::Parse($hex.Substring(4, 2), [NumberStyles]::HexNumber)
    return [Color]::new($_r, $_g, $_b)
  }

  static [Color] FromName([string]$name) {
    return [ColorTable]::GetColor($name)
  }

  static [Color] FromConsoleColor([ConsoleColor]$color) {
    $c = switch ($color) {
      ([ConsoleColor]::Black) { [ColorTable]::GetColor(0); break }
      ([ConsoleColor]::DarkRed) { [ColorTable]::GetColor(1); break }
      ([ConsoleColor]::DarkGreen) { [ColorTable]::GetColor(2); break }
      ([ConsoleColor]::DarkYellow) { [ColorTable]::GetColor(3); break }
      ([ConsoleColor]::DarkBlue) { [ColorTable]::GetColor(4); break }
      ([ConsoleColor]::DarkMagenta) { [ColorTable]::GetColor(5); break }
      ([ConsoleColor]::DarkCyan) { [ColorTable]::GetColor(6); break }
      ([ConsoleColor]::Gray) { [ColorTable]::GetColor(7); break }
      ([ConsoleColor]::DarkGray) { [ColorTable]::GetColor(8); break }
      ([ConsoleColor]::Red) { [ColorTable]::GetColor(9); break }
      ([ConsoleColor]::Green) { [ColorTable]::GetColor(10); break }
      ([ConsoleColor]::Yellow) { [ColorTable]::GetColor(11); break }
      ([ConsoleColor]::Blue) { [ColorTable]::GetColor(12); break }
      ([ConsoleColor]::Magenta) { [ColorTable]::GetColor(13); break }
      ([ConsoleColor]::Cyan) { [ColorTable]::GetColor(14); break }
      ([ConsoleColor]::White) { [ColorTable]::GetColor(15); break }
      default { [Color]::Default; break }
    }
    return $c
  }
}

# .EXAMPLE
# [rgb]"AntiqueWhite"
# Red Green Blue
# --- ----- ----
# 250   235  215
class RGB {
  [ValidateRange(0, 255)]
  hidden [int]$_Red
  [ValidateRange(0, 255)]
  hidden [int]$_Green
  [ValidateRange(0, 255)]
  hidden [int]$_Blue

  static [rgb] $Red = [rgb]::new(255, 0, 0)
  static [rgb] $DarkRed = [rgb]::new(128, 0, 0)
  static [rgb] $Green = [rgb]::new(0, 255, 0)
  static [rgb] $DarkGreen = [rgb]::new(0, 128, 0)
  static [rgb] $Blue = [rgb]::new(0, 0, 255)
  static [rgb] $DarkBlue = [rgb]::new(0, 0, 128)
  static [rgb] $White = [rgb]::new(255, 255, 255)
  static [rgb] $Black = [rgb]::new(0, 0, 0)
  static [rgb] $Yellow = [rgb]::new(255, 255, 0)
  static [rgb] $DarkGray = [rgb]::new(128, 128, 128)
  static [rgb] $Gray = [rgb]::new(192, 192, 192)
  static [rgb] $LightGray = [rgb]::new(238, 237, 240)
  static [rgb] $Cyan = [rgb]::new(0, 255, 255)
  static [rgb] $DarkCyan = [rgb]::new(0, 128, 128)
  static [rgb] $Magenta = [rgb]::new(255, 0, 255)
  static [rgb] $PSBlue = [rgb]::new(1, 36, 86)
  static [rgb] $AliceBlue = [rgb]::new(240, 248, 255)
  static [rgb] $AntiqueWhite = [rgb]::new(250, 235, 215)
  static [rgb] $AquaMarine = [rgb]::new(127, 255, 212)
  static [rgb] $Azure = [rgb]::new(240, 255, 255)
  static [rgb] $Beige = [rgb]::new(245, 245, 220)
  static [rgb] $Bisque = [rgb]::new(255, 228, 196)
  static [rgb] $BlanchedAlmond = [rgb]::new(255, 235, 205)
  static [rgb] $BlueViolet = [rgb]::new(138, 43, 226)
  static [rgb] $Brown = [rgb]::new(165, 42, 42)
  static [rgb] $Burlywood = [rgb]::new(222, 184, 135)
  static [rgb] $CadetBlue = [rgb]::new(95, 158, 160)
  static [rgb] $Chartreuse = [rgb]::new(127, 255, 0)
  static [rgb] $Chocolate = [rgb]::new(210, 105, 30)
  static [rgb] $Coral = [rgb]::new(255, 127, 80)
  static [rgb] $CornflowerBlue = [rgb]::new(100, 149, 237)
  static [rgb] $CornSilk = [rgb]::new(255, 248, 220)
  static [rgb] $Crimson = [rgb]::new(220, 20, 60)
  static [rgb] $DarkGoldenrod = [rgb]::new(184, 134, 11)
  static [rgb] $DarkKhaki = [rgb]::new(189, 183, 107)
  static [rgb] $DarkMagenta = [rgb]::new(139, 0, 139)
  static [rgb] $DarkOliveGreen = [rgb]::new(85, 107, 47)
  static [rgb] $DarkOrange = [rgb]::new(255, 140, 0)
  static [rgb] $DarkOrchid = [rgb]::new(153, 50, 204)
  static [rgb] $DarkSalmon = [rgb]::new(233, 150, 122)
  static [rgb] $DarkSeaGreen = [rgb]::new(143, 188, 143)
  static [rgb] $DarkSlateBlue = [rgb]::new(72, 61, 139)
  static [rgb] $DarkSlateGray = [rgb]::new(47, 79, 79)
  static [rgb] $DarkTurquoise = [rgb]::new(0, 206, 209)
  static [rgb] $DarkViolet = [rgb]::new(148, 0, 211)
  static [rgb] $DeepPink = [rgb]::new(255, 20, 147)
  static [rgb] $DeepSkyBlue = [rgb]::new(0, 191, 255)
  static [rgb] $DimGray = [rgb]::new(105, 105, 105)
  static [rgb] $DodgerBlue = [rgb]::new(30, 144, 255)
  static [rgb] $FireBrick = [rgb]::new(178, 34, 34)
  static [rgb] $FloralWhite = [rgb]::new(255, 250, 240)
  static [rgb] $ForestGreen = [rgb]::new(34, 139, 34)
  static [rgb] $GainsBoro = [rgb]::new(220, 220, 220)
  static [rgb] $GhostWhite = [rgb]::new(248, 248, 255)
  static [rgb] $Gold = [rgb]::new(255, 215, 0)
  static [rgb] $Goldenrod = [rgb]::new(218, 165, 32)
  static [rgb] $GreenYellow = [rgb]::new(173, 255, 47)
  static [rgb] $HoneyDew = [rgb]::new(240, 255, 240)
  static [rgb] $HotPink = [rgb]::new(255, 105, 180)
  static [rgb] $IndianRed = [rgb]::new(205, 92, 92)
  static [rgb] $Indigo = [rgb]::new(75, 0, 130)
  static [rgb] $Ivory = [rgb]::new(255, 255, 240)
  static [rgb] $Khaki = [rgb]::new(240, 230, 140)
  static [rgb] $Lavender = [rgb]::new(230, 230, 250)
  static [rgb] $LavenderBlush = [rgb]::new(255, 240, 245)
  static [rgb] $LawnGreen = [rgb]::new(124, 252, 0)
  static [rgb] $LemonChiffon = [rgb]::new(255, 250, 205)
  static [rgb] $LightBlue = [rgb]::new(173, 216, 230)
  static [rgb] $LightCoral = [rgb]::new(240, 128, 128)
  static [rgb] $LightCyan = [rgb]::new(224, 255, 255)
  static [rgb] $LightGoldenrodYellow = [rgb]::new(250, 250, 210)
  static [rgb] $LightPink = [rgb]::new(255, 182, 193)
  static [rgb] $LightSalmon = [rgb]::new(255, 160, 122)
  static [rgb] $LightSeaGreen = [rgb]::new(32, 178, 170)
  static [rgb] $LightSkyBlue = [rgb]::new(135, 206, 250)
  static [rgb] $LightSlateGray = [rgb]::new(119, 136, 153)
  static [rgb] $LightSteelBlue = [rgb]::new(176, 196, 222)
  static [rgb] $LightYellow = [rgb]::new(255, 255, 224)
  static [rgb] $LimeGreen = [rgb]::new(50, 205, 50)
  static [rgb] $Linen = [rgb]::new(250, 240, 230)
  static [rgb] $MediumAquaMarine = [rgb]::new(102, 205, 170)
  static [rgb] $MediumOrchid = [rgb]::new(186, 85, 211)
  static [rgb] $MediumPurple = [rgb]::new(147, 112, 219)
  static [rgb] $MediumSeaGreen = [rgb]::new(60, 179, 113)
  static [rgb] $MediumSlateBlue = [rgb]::new(123, 104, 238)
  static [rgb] $MediumSpringGreen = [rgb]::new(0, 250, 154)
  static [rgb] $MediumTurquoise = [rgb]::new(72, 209, 204)
  static [rgb] $MediumVioletRed = [rgb]::new(199, 21, 133)
  static [rgb] $MidnightBlue = [rgb]::new(25, 25, 112)
  static [rgb] $MintCream = [rgb]::new(245, 255, 250)
  static [rgb] $MistyRose = [rgb]::new(255, 228, 225)
  static [rgb] $Moccasin = [rgb]::new(255, 228, 181)
  static [rgb] $NavajoWhite = [rgb]::new(255, 222, 173)
  static [rgb] $OldLace = [rgb]::new(253, 245, 230)
  static [rgb] $Olive = [rgb]::new(128, 128, 0)
  static [rgb] $OliveDrab = [rgb]::new(107, 142, 35)
  static [rgb] $Orange = [rgb]::new(255, 165, 0)
  static [rgb] $OrangeRed = [rgb]::new(255, 69, 0)
  static [rgb] $Orchid = [rgb]::new(218, 112, 214)
  static [rgb] $PaleGoldenrod = [rgb]::new(238, 232, 170)
  static [rgb] $PaleGreen = [rgb]::new(152, 251, 152)
  static [rgb] $PaleTurquoise = [rgb]::new(175, 238, 238)
  static [rgb] $PaleVioletRed = [rgb]::new(219, 112, 147)
  static [rgb] $PapayaWhip = [rgb]::new(255, 239, 213)
  static [rgb] $PeachPuff = [rgb]::new(255, 218, 185)
  static [rgb] $Peru = [rgb]::new(205, 133, 63)
  static [rgb] $Pink = [rgb]::new(255, 192, 203)
  static [rgb] $Plum = [rgb]::new(221, 160, 221)
  static [rgb] $PowderBlue = [rgb]::new(176, 224, 230)
  static [rgb] $Purple = [rgb]::new(128, 0, 128)
  static [rgb] $RosyBrown = [rgb]::new(188, 143, 143)
  static [rgb] $RoyalBlue = [rgb]::new(65, 105, 225)
  static [rgb] $SaddleBrown = [rgb]::new(139, 69, 19)
  static [rgb] $Salmon = [rgb]::new(250, 128, 114)
  static [rgb] $SandyBrown = [rgb]::new(244, 164, 96)
  static [rgb] $SeaGreen = [rgb]::new(46, 139, 87)
  static [rgb] $SeaShell = [rgb]::new(255, 245, 238)
  static [rgb] $Sienna = [rgb]::new(160, 82, 45)
  static [rgb] $SkyBlue = [rgb]::new(135, 206, 235)
  static [rgb] $SlateBlue = [rgb]::new(106, 90, 205)
  static [rgb] $SlateGray = [rgb]::new(112, 128, 144)
  static [rgb] $Snow = [rgb]::new(255, 250, 250)
  static [rgb] $SpringGreen = [rgb]::new(0, 255, 127)
  static [rgb] $SteelBlue = [rgb]::new(70, 130, 180)
  static [rgb] $Tan = [rgb]::new(210, 180, 140)
  static [rgb] $Thistle = [rgb]::new(216, 191, 216)
  static [rgb] $Tomato = [rgb]::new(255, 99, 71)
  static [rgb] $Turquoise = [rgb]::new(64, 224, 208)
  static [rgb] $Violet = [rgb]::new(238, 130, 238)
  static [rgb] $Wheat = [rgb]::new(245, 222, 179)
  static [rgb] $WhiteSmoke = [rgb]::new(245, 245, 245)
  static [rgb] $YellowGreen = [rgb]::new(154, 205, 50)

  RGB() {
    $this._initialize()
  }
  RGB([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) { throw [System.ArgumentException]::new("Color name cannot be null or whitespace.") }
    $IsValid = [rgb].GetProperties().Name.ToLower().Contains($Name.ToLower())
    if (!$IsValid) { throw [System.InvalidCastException]::new("Color name '$Name' is not valid. see [ConsoleWriter]::Colors for a list of valid colors OR ue: [rgb].GetProperties().Where({ `$_.IsStatic  }).Name") }
    [RGB]$c = [rgb]::$Name
    $this._Red = $c.Red
    $this._Green = $c.Green
    $this._Blue = $c.Blue
    $this._initialize()
  }
  RGB([int]$r, [int]$g, [int]$b) {
    $this._Red = $r
    $this._Green = $g
    $this._Blue = $b
    $this._initialize()
  }
  hidden [void] _initialize() {
    $this.PsObject.Properties.Add([PSAliasproperty]::new("Red", "_Red"))
    $this.PsObject.Properties.Add([PSAliasproperty]::new("Green", "_Green"))
    $this.PsObject.Properties.Add([PSAliasproperty]::new("Blue", "_Blue"))
  }
  [tuple[int, int, int]] ToHsv() {
    return $this.ToHsv($this._Red, $this._Green, $this._Blue)
  }
  [tuple[int, int, int]] ToHsv([rgb]$RGB) {
    return $this.ToHsv($RGB.Red, $RGB.Green, $RGB.Blue)
  }
  [tuple[int, int, int]] ToHsv([int]$Red, [int]$Green, [int]$Blue) {
    $null = [RGB]::new($Red, $Green, $Blue) # for validation
    $redPercent = $Red / 255.0
    $greenPercent = $Green / 255.0
    $bluePercent = $Blue / 255.0

    $max = [Math]::Max([Math]::Max($redPercent, $greenPercent), $bluePercent)
    $min = [Math]::Min([Math]::Min($redPercent, $greenPercent), $bluePercent)
    $delta = $max - $min

    $saturation = 0
    $value = 0
    $hue = 0

    if ($delta -eq 0) {
      $hue = 0
    } elseif ($max -eq $redPercent) {
      $hue = 60 * ((($greenPercent - $bluePercent) / $delta) % 6)
    } elseif ($max -eq $greenPercent) {
      $hue = 60 * ((($bluePercent - $redPercent) / $delta) + 2)
    } elseif ($max -eq $bluePercent) {
      $hue = 60 * ((($redPercent - $greenPercent) / $delta) + 4)
    }
    if ($hue -lt 0) { $hue = 360 + $hue }

    if ($max -eq 0) {
      $saturation = 0
    } else {
      $saturation = $delta / $max * 100
    }
    $value = $max * 100

    return [tuple]::Create([int]$hue, [int]$saturation, [int]$value)
  }
  [RGB] FromHsl([int]$Hue, [int]$Saturation, [int]$Lightness) {
    $huePercent = $Hue / 360.0
    $saturationPercent = $Saturation / 100.0
    $lightnessPercent = $Lightness / 100.0
    ($r, $g, $b) = if ($saturationPercent -eq 0) {
      $lightnessPercent,
      $lightnessPercent,
      $lightnessPercent
    } else {
      $q = ($lightnessPercent -lt 0.5) ? ($lightnessPercent * (1 + $saturationPercent)) : ($lightnessPercent + $saturationPercent - ($lightnessPercent * $saturationPercent))
      $p = 2 * $lightnessPercent - $q

      [rgb]::FromPQT($p, $q, ($huePercent + (1 / 3))),
      [rgb]::FromPQT($p, $q, $huePercent),
      [rgb]::FromPQT($p, $q, ($huePercent - (1 / 3)))
    }
    return [RGB]::new([int]($r * 255), [int]($g * 255), [int]($b * 255))
  }
  static [int] FromPQT([double]$P, [double]$Q, [double]$T) {
    if ($T -lt 0) { $T += 1 }
    if ($T -gt 1) { $T -= 1 }

    if ($T -lt (1 / 6)) { return $P + ($Q - $P) * 6 * $T }

    if ($T -lt (1 / 2)) { return $Q }
    if ($T -lt (2 / 3)) { return $P + ($Q - $P) * (2 / 3 - $T) * 6 }

    return $P
  }
  [int] GetLightness([int]$Red, [int]$Green, [int]$Blue) {
    $redPercent = $Red / 255.0
    $greenPercent = $Green / 255.0
    $bluePercent = $Blue / 255.0
    $max = [Math]::Max([Math]::Max($redPercent, $greenPercent), $bluePercent)
    $min = [Math]::Min([Math]::Min($redPercent, $greenPercent), $bluePercent)

    return ($max + $min) / 2
  }
  [string] GetCategory([int]$Hue, [int]$Saturation, [int]$Value) {
    $categories = @{
      "02 Red"    = @(0..20 + 350..360)
      "03 Orange" = @(21..45)
      "04 Yellow" = @(46..60)
      "05 Green"  = @(61..108)
      "06 Green2" = @(109..150)
      "07 Cyan"   = @(151..190)
      "08 Blue"   = @(191..220)
      "09 Blue2"  = @(221..240)
      "10 Purple" = @(241..280)
      "11 Pink1"  = @(281..300)
      "12 Pink"   = @(301..350)
    }

    if ($Saturation -lt 15) {
      if ($Value -lt 40) {
        return "00 Grey"
      }
      return "00 GreyZMud"
    }
    $res = @()
    foreach ($category in $categories.GetEnumerator()) {
      if ($Hue -in $category.Value) {
        $cat = $category.Key
        if ($Saturation -lt 2) {
          $cat = $cat + "ZMud"
        }
        $res += $cat
      }
    }
    return $res
  }
  [string] ToString() {
    return [rgb].GetProperties().Name.Where({ [rgb]::$_ -eq $this })
  }
}