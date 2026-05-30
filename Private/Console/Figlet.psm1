using namespace System
using namespace System.Collections.Generic
using namespace System.Text
using namespace System.IO

using module ..\Enums.psm1
using module ..\Abstracts.psm1
using module .\Colors.psm1
using module .\Rendering.psm1

# ---------------------------------------------------------------------------
# FigletHeader  – parsed from the first line of a .flf font file
# ---------------------------------------------------------------------------
class FigletHeader {
  [char]$Hardblank
  [int]$Height
  [int]$Baseline
  [int]$MaxLength
  [int]$OldLayout
  [int]$CommentLines
  [int]$FullLayout      # 0 means "not present"
  [bool]$HasFullLayout
}

# ---------------------------------------------------------------------------
# FigletCharacter  – one glyph from the font
# ---------------------------------------------------------------------------
class FigletCharacter {
  [int]$Code
  [int]$Width
  [int]$Height
  [string[]]$Lines

  FigletCharacter([int]$code, [string[]]$lines) {
    $this.Code = $code
    $this.Lines = $lines
    $max = 0
    foreach ($l in $lines) { if ($l.Length -gt $max) { $max = $l.Length } }
    $this.Width = $max
    $this.Height = $lines.Length
  }
}

# ---------------------------------------------------------------------------
# FigletFontParser – reads .flf source text and builds a FigletFont
# ---------------------------------------------------------------------------
class FigletFontParser {
  static [FigletFont] Parse([string]$source) {
    $lines = $source -split "`r?`n"
    if ($lines.Length -eq 0) { throw 'Could not read header line' }

    [FigletHeader]$header = [FigletFontParser]::ParseHeader($lines[0])
    [char]$eolMarker = [FigletFontParser]::ParseEndOfLineMarker($lines, $header)

    $index = 32
    $indexOverridden = $false
    $hasOverriddenIndex = $false
    $buffer = [List[string]]::new()
    $characters = [List[FigletCharacter]]::new()
    $accumulatedHeight = 0

    for ($i = $header.CommentLines + 1; $i -lt $lines.Length; $i++) {
      $line = $lines[$i]
      if ($null -eq $line) { continue }

      # Check if this is a Unicode index override line (no eolMarker at end)
      if (-not $line.EndsWith($eolMarker.ToString())) {
        $words = $line.Trim() -split '\s+'
        $newIndex = 0
        if ($words.Length -gt 0 -and [FigletFontParser]::TryParseIndex($words[0], [ref]$newIndex)) {
          $index = $newIndex
          $indexOverridden = $true
          $hasOverriddenIndex = $true
          $accumulatedHeight = 0
          continue
        }
      }

      if ($hasOverriddenIndex -and -not $indexOverridden) { continue }

      $buffer.Add($line.TrimEnd([char[]]@($eolMarker)))
      $accumulatedHeight++

      if ($accumulatedHeight -eq $header.Height) {
        $characters.Add([FigletCharacter]::new($index, $buffer.ToArray()))
        $buffer.Clear()

        if (-not $hasOverriddenIndex) { $index++ }
        $indexOverridden = $false
        $accumulatedHeight = 0
      }
    }

    return [FigletFont]::new($characters, $header)
  }

  static hidden [char] ParseEndOfLineMarker([string[]]$lines, [FigletHeader]$header) {
    $idx = $header.CommentLines + 1
    if ($idx -lt $lines.Length) {
      $first = $lines[$idx].Trim()
      if ($first.Length -gt 0) { return $first[$first.Length - 1] }
    }
    return '@'
  }

  static hidden [bool] TryParseIndex([string]$indexStr, [ref]$result) {
    $style = [Globalization.NumberStyles]::Integer
    if ($indexStr.StartsWith('0x', [StringComparison]::OrdinalIgnoreCase)) {
      $indexStr = $indexStr.Substring(2)
      $style = [Globalization.NumberStyles]::HexNumber
    }
    $val = 0
    if ([int]::TryParse($indexStr, $style, [Globalization.CultureInfo]::InvariantCulture, [ref]$val)) {
      $result.Value = $val
      return $true
    }
    return $false
  }

  static hidden [FigletHeader] ParseHeader([string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) { throw 'Invalid Figlet font' }
    $parts = $text -split ' +' | Where-Object { $_ -ne '' }
    if ($parts.Length -lt 6) { throw 'Invalid Figlet font header' }
    if (-not [FigletFontParser]::IsValidSignature($parts[0])) {
      throw 'Invalid Figlet font header signature'
    }

    $h = [FigletHeader]::new()
    $h.Hardblank = $parts[0][5]
    $h.Height = [int]::Parse($parts[1], [Globalization.CultureInfo]::InvariantCulture)
    $h.Baseline = [int]::Parse($parts[2], [Globalization.CultureInfo]::InvariantCulture)
    $h.MaxLength = [int]::Parse($parts[3], [Globalization.CultureInfo]::InvariantCulture)
    $h.OldLayout = [int]::Parse($parts[4], [Globalization.CultureInfo]::InvariantCulture)
    $h.CommentLines = [int]::Parse($parts[5], [Globalization.CultureInfo]::InvariantCulture)

    if ($parts.Length -gt 7) {
      $fl = 0
      if ([int]::TryParse($parts[7], [Globalization.NumberStyles]::Integer,
          [Globalization.CultureInfo]::InvariantCulture, [ref]$fl)) {
        $h.FullLayout = $fl
        $h.HasFullLayout = $true
      }
    }
    return $h
  }

  static hidden [bool] IsValidSignature([string]$s) {
    return $s.Length -ge 6 -and $s[0] -eq 'f' -and $s[1] -eq 'l' -and
    $s[2] -eq 'f' -and $s[3] -eq '2' -and $s[4] -eq 'a'
  }
}

# ---------------------------------------------------------------------------
# FigletFont  – holds all parsed glyphs + metadata
# ---------------------------------------------------------------------------
# .EXAMPLE
# # Get the default font
# [FigletFont]::Default()
# .EXAMPLE
# # Get a specific font
# [FigletFont]"DEFAULT_3D"
# .EXAMPLE
# # Get all available fonts
# [FigletFont]::GetAvailableFonts()
# .EXAMPLE
# # Load a font from a file
# [FigletFont]::Load("fonts\standard.flf")
# .EXAMPLE
# # Render a string
# [FigletFont]::Default().Render("Hello World")
# .EXAMPLE
# # Render a string with alignment
# [FigletFont]::Default().Render("Hello World", "Center", "Middle")
# .EXAMPLE
# # Render a string with overflow
# [FigletFont]::Default().Render("Hello World", "Center", "Middle", "Crop")

class FigletFont {
  hidden [Dictionary[int, FigletCharacter]]$_characters
  # fonts are based on files in fonts folder
  # ie: ls fonts/ -file | % { '  static [FigletFont]$' + $_.BaseName + ' = ' + "`"$($_.BaseName.ToLowerInvariant())`"" }
  static [FigletFont]$ACROBATIC
  static [FigletFont]$ALLIGATOR
  static [FigletFont]$ALLIGATOR2
  static [FigletFont]$ALLIGATOR3
  static [FigletFont]$ALPHA
  static [FigletFont]$ALPHABET
  static [FigletFont]$AMC_3_LINE
  static [FigletFont]$AMC_3_LIV1
  static [FigletFont]$AMC_AAA01
  static [FigletFont]$AMC_NEKO
  static [FigletFont]$AMC_RAZOR
  static [FigletFont]$AMC_RAZOR2
  static [FigletFont]$AMC_SLASH
  static [FigletFont]$AMC_SLIDER
  static [FigletFont]$AMC_THIN
  static [FigletFont]$AMC_TUBES
  static [FigletFont]$AMC_UNTITLED
  static [FigletFont]$AMC3LINE
  static [FigletFont]$AMC3LIV1
  static [FigletFont]$AMCAAA01
  static [FigletFont]$AMCNEKO
  static [FigletFont]$AMCRAZO2
  static [FigletFont]$AMCRAZOR
  static [FigletFont]$AMCSLASH
  static [FigletFont]$AMCSLDER
  static [FigletFont]$AMCTHIN
  static [FigletFont]$AMCTUBES
  static [FigletFont]$AMCUN1
  static [FigletFont]$ANSI_REGULAR
  static [FigletFont]$ANSI_SHADOW
  static [FigletFont]$ARROWS
  static [FigletFont]$ASCII_3D
  static [FigletFont]$ASCII_NEW_ROMAN_2
  static [FigletFont]$ASCII_NEW_ROMAN
  static [FigletFont]$AVATAR
  static [FigletFont]$B1FF
  static [FigletFont]$BANNER
  static [FigletFont]$BANNER3_D
  static [FigletFont]$BANNER3
  static [FigletFont]$BANNER4
  static [FigletFont]$BARBWIRE
  static [FigletFont]$BASIC
  static [FigletFont]$BEAR
  static [FigletFont]$BELL
  static [FigletFont]$BENJAMIN
  static [FigletFont]$BIG_CHIEF
  static [FigletFont]$BIG_MONEY_NE
  static [FigletFont]$BIG_MONEY_NW
  static [FigletFont]$BIG_MONEY_SE
  static [FigletFont]$BIG_MONEY_SW
  static [FigletFont]$BIG
  static [FigletFont]$BIGCHIEF
  static [FigletFont]$BIGFIG
  static [FigletFont]$BINARY
  static [FigletFont]$BLOCK
  static [FigletFont]$BLOCKS
  static [FigletFont]$BLOODY
  static [FigletFont]$BOLGER
  static [FigletFont]$BRACED
  static [FigletFont]$BRIGHT
  static [FigletFont]$BROADWAY_KB_2
  static [FigletFont]$BROADWAY_KB
  static [FigletFont]$BROADWAY
  static [FigletFont]$BUBBLE
  static [FigletFont]$BULBHEAD
  static [FigletFont]$CALGPHY2
  static [FigletFont]$CALIGRAPHY
  static [FigletFont]$CALIGRAPHY2
  static [FigletFont]$CALVIN_S
  static [FigletFont]$CARDS
  static [FigletFont]$CATWALK
  static [FigletFont]$CHISELED
  static [FigletFont]$CHUNKY
  static [FigletFont]$COINSTAK
  static [FigletFont]$COLA
  static [FigletFont]$COLOSSAL
  static [FigletFont]$COMPUTER
  static [FigletFont]$CONTESSA
  static [FigletFont]$CONTRAST
  static [FigletFont]$COSMIC
  static [FigletFont]$COSMIKE
  static [FigletFont]$CRAWFORD
  static [FigletFont]$CRAWFORD2
  static [FigletFont]$CRAZY
  static [FigletFont]$CRICKET
  static [FigletFont]$CURSIVE
  static [FigletFont]$CYBERLARGE
  static [FigletFont]$CYBERMEDIUM
  static [FigletFont]$CYBERSMALL
  static [FigletFont]$CYGNET
  static [FigletFont]$DANC4
  static [FigletFont]$DANCING_FONT
  static [FigletFont]$DANCINGFONT
  static [FigletFont]$DECIMAL
  static [FigletFont]$DEF_LEPPARD
  static [FigletFont]$DEFAULT_3D
  static [FigletFont]$DEFLEPPARD
  static [FigletFont]$DELTA_CORPS_PRIEST_1
  static [FigletFont]$DIAGONAL_3D_2
  static [FigletFont]$DIAGONAL_3D
  static [FigletFont]$DIAMOND
  static [FigletFont]$DIET_COLA
  static [FigletFont]$DIETCOLA
  static [FigletFont]$DIGITAL
  static [FigletFont]$DOH
  static [FigletFont]$DOOM
  static [FigletFont]$DOS_REBEL
  static [FigletFont]$DOSREBEL
  static [FigletFont]$DOT_MATRIX
  static [FigletFont]$DOTMATRIX
  static [FigletFont]$DOUBLE_SHORTS
  static [FigletFont]$DOUBLE
  static [FigletFont]$DOUBLESHORTS
  static [FigletFont]$DR_PEPPER
  static [FigletFont]$DRPEPPER
  static [FigletFont]$DWHISTLED
  static [FigletFont]$EFTI_CHESS
  static [FigletFont]$EFTI_FONT
  static [FigletFont]$EFTI_ITALIC
  static [FigletFont]$EFTI_PITI
  static [FigletFont]$EFTI_ROBOT
  static [FigletFont]$EFTI_WALL
  static [FigletFont]$EFTI_WATER
  static [FigletFont]$EFTICHESS
  static [FigletFont]$EFTIFONT
  static [FigletFont]$EFTIPITI
  static [FigletFont]$EFTIROBOT
  static [FigletFont]$EFTITALIC
  static [FigletFont]$EFTIWALL
  static [FigletFont]$EFTIWATER
  static [FigletFont]$ELECTRONIC
  static [FigletFont]$ELITE
  static [FigletFont]$EPIC
  static [FigletFont]$FENDER
  static [FigletFont]$FILTER_1
  static [FigletFont]$FIRE_FONT_K
  static [FigletFont]$FIRE_FONT_S
  static [FigletFont]$FLIPPED
  static [FigletFont]$FLOWER_POWER
  static [FigletFont]$FLOWERPOWER
  static [FigletFont]$FOUR_MAX
  static [FigletFont]$FOUR_TOPS
  static [FigletFont]$FOURTOPS
  static [FigletFont]$FRAKTUR
  static [FigletFont]$FUN_FACE
  static [FigletFont]$FUN_FACES
  static [FigletFont]$FUNFACE
  static [FigletFont]$FUNFACES
  static [FigletFont]$FUZZY
  static [FigletFont]$GEORGI16
  static [FigletFont]$GEORGIA11
  static [FigletFont]$GHOST
  static [FigletFont]$GHOULISH
  static [FigletFont]$GLENYN
  static [FigletFont]$GOOFY
  static [FigletFont]$GOTHIC
  static [FigletFont]$GRACEFUL
  static [FigletFont]$GRADIENT
  static [FigletFont]$GRAFFITI
  static [FigletFont]$GREEK
  static [FigletFont]$HALFIWI
  static [FigletFont]$HEART_LEFT
  static [FigletFont]$HEART_RIGHT
  static [FigletFont]$HENRY_3D
  static [FigletFont]$HENRY3D
  static [FigletFont]$HEX
  static [FigletFont]$HIEROGLYPHS
  static [FigletFont]$HOLLYWOOD
  static [FigletFont]$HORIZONTAL_LEFT
  static [FigletFont]$HORIZONTAL_RIGHT
  static [FigletFont]$HORIZONTALLEFT
  static [FigletFont]$HORIZONTALRIGHT
  static [FigletFont]$ICL_1900
  static [FigletFont]$IMPOSSIBLE
  static [FigletFont]$INVITA
  static [FigletFont]$ISOMETRIC1
  static [FigletFont]$ISOMETRIC2
  static [FigletFont]$ISOMETRIC3
  static [FigletFont]$ISOMETRIC4
  static [FigletFont]$ITALIC
  static [FigletFont]$IVRIT
  static [FigletFont]$JACKY
  static [FigletFont]$JAZMINE
  static [FigletFont]$JERUSALEM
  static [FigletFont]$JS_BLOCK_LETTERS
  static [FigletFont]$JS_BRACKET_LETTERS
  static [FigletFont]$JS_CAPITAL_CURVES
  static [FigletFont]$JS_CURSIVE
  static [FigletFont]$JS_STICK_LETTERS
  static [FigletFont]$KATAKANA
  static [FigletFont]$KBAN
  static [FigletFont]$KEYBOARD
  static [FigletFont]$KNOB
  static [FigletFont]$KOHOLINT
  static [FigletFont]$KOMPAKTBLK
  static [FigletFont]$KONTO_SLANT
  static [FigletFont]$KONTO
  static [FigletFont]$KONTOSLANT
  static [FigletFont]$LARRY_3D_2
  static [FigletFont]$LARRY_3D
  static [FigletFont]$LARRY3D
  static [FigletFont]$LCD
  static [FigletFont]$LEAN
  static [FigletFont]$LETTERS
  static [FigletFont]$LIL_DEVIL
  static [FigletFont]$LILDEVIL
  static [FigletFont]$LINE_BLOCKS
  static [FigletFont]$LINEBLOCKS
  static [FigletFont]$LINES_3D
  static [FigletFont]$LINUX
  static [FigletFont]$LOCKERGNOME
  static [FigletFont]$MADRID
  static [FigletFont]$MARQUEE
  static [FigletFont]$MAXFOUR
  static [FigletFont]$MAXIWI
  static [FigletFont]$MERLIN1
  static [FigletFont]$MERLIN2
  static [FigletFont]$MIKE
  static [FigletFont]$MINI
  static [FigletFont]$MINIWI
  static [FigletFont]$MIRROR
  static [FigletFont]$MNEMONIC
  static [FigletFont]$MODULAR
  static [FigletFont]$MONO9
  static [FigletFont]$MORSE
  static [FigletFont]$MORSE2
  static [FigletFont]$MOSCOW
  static [FigletFont]$MSHEBREW210
  static [FigletFont]$MUZZLE
  static [FigletFont]$NANCYJ_FANCY
  static [FigletFont]$NANCYJ_IMPROVED
  static [FigletFont]$NANCYJ_UNDERLINED
  static [FigletFont]$NANCYJ
  static [FigletFont]$NIPPLES
  static [FigletFont]$NSCRIPT
  static [FigletFont]$NT_GREEK
  static [FigletFont]$NTGREEK
  static [FigletFont]$NV_SCRIPT
  static [FigletFont]$O8
  static [FigletFont]$OBLIQUE_5LINE_2
  static [FigletFont]$OBLIQUE_5LINE
  static [FigletFont]$OCTAL
  static [FigletFont]$OGRE
  static [FigletFont]$OLD_BANNER
  static [FigletFont]$OLDBANNER
  static [FigletFont]$ONE_ROW
  static [FigletFont]$OS2
  static [FigletFont]$PATORJK_HEX
  static [FigletFont]$PATORJKS_CHEESE
  static [FigletFont]$PAWP
  static [FigletFont]$PEAKS_SLANT
  static [FigletFont]$PEAKS
  static [FigletFont]$PEAKSSLANT
  static [FigletFont]$PEBBLES
  static [FigletFont]$PEPPER
  static [FigletFont]$PIXEL_3X5
  static [FigletFont]$POISON
  static [FigletFont]$PUFFY
  static [FigletFont]$PUZZLE
  static [FigletFont]$PYRAMID
  static [FigletFont]$RAMMSTEIN
  static [FigletFont]$RECTANGLES
  static [FigletFont]$RED_PHOENIX
  static [FigletFont]$RELIEF
  static [FigletFont]$RELIEF2
  static [FigletFont]$REV
  static [FigletFont]$REVERSE
  static [FigletFont]$ROMAN
  static [FigletFont]$ROT13
  static [FigletFont]$ROTATED
  static [FigletFont]$ROUNDED
  static [FigletFont]$ROWAN_CAP
  static [FigletFont]$ROWANCAP
  static [FigletFont]$ROZZO
  static [FigletFont]$RUNIC
  static [FigletFont]$RUNYC
  static [FigletFont]$S_BLOOD
  static [FigletFont]$S_RELIEF
  static [FigletFont]$SANTA_CLARA
  static [FigletFont]$SANTACLARA
  static [FigletFont]$SBLOOD
  static [FigletFont]$SCRIPT
  static [FigletFont]$SERIFCAP
  static [FigletFont]$SHADOW
  static [FigletFont]$SHIMROD
  static [FigletFont]$SHORT
  static [FigletFont]$SIX_FO
  static [FigletFont]$SL_SCRIPT
  static [FigletFont]$SLANT_RELIEF
  static [FigletFont]$SLANT
  static [FigletFont]$SLIDE
  static [FigletFont]$SLSCRIPT
  static [FigletFont]$SMALL_CAPS
  static [FigletFont]$SMALL_ISOMETRIC1
  static [FigletFont]$SMALL_KEYBOARD
  static [FigletFont]$SMALL_POISON
  static [FigletFont]$SMALL_SCRIPT
  static [FigletFont]$SMALL_SHADOW
  static [FigletFont]$SMALL_SLANT
  static [FigletFont]$SMALL_TENGWAR
  static [FigletFont]$SMALL
  static [FigletFont]$SMALLCAPS
  static [FigletFont]$SMISOME1
  static [FigletFont]$SMKEYBOARD
  static [FigletFont]$SMPOISON
  static [FigletFont]$SMSCRIPT
  static [FigletFont]$SMSHADOW
  static [FigletFont]$SMSLANT
  static [FigletFont]$SMTENGWAR
  static [FigletFont]$SOFT
  static [FigletFont]$SPEED
  static [FigletFont]$SPLIFF
  static [FigletFont]$STACEY
  static [FigletFont]$STAMPATE
  static [FigletFont]$STAMPATELLO
  static [FigletFont]$STANDARD
  static [FigletFont]$STAR_STRIPS
  static [FigletFont]$STAR_WARS
  static [FigletFont]$STARSTRIPS
  static [FigletFont]$STARWARS
  static [FigletFont]$STELLAR
  static [FigletFont]$STENCIL
  static [FigletFont]$STFOREK
  static [FigletFont]$STICK_LETTERS
  static [FigletFont]$STOP
  static [FigletFont]$STRAIGHT
  static [FigletFont]$STRONGER_THAN_ALL
  static [FigletFont]$SUB_ZERO
  static [FigletFont]$SWAMP_LAND
  static [FigletFont]$SWAMPLAND
  static [FigletFont]$SWAN
  static [FigletFont]$SWEET
  static [FigletFont]$TANJA
  static [FigletFont]$TENGWAR
  static [FigletFont]$TERM
  static [FigletFont]$TERMINUS_DOTS
  static [FigletFont]$TERMINUS
  static [FigletFont]$TEST1
  static [FigletFont]$THE_EDGE
  static [FigletFont]$THICK
  static [FigletFont]$THIN
  static [FigletFont]$THIS
  static [FigletFont]$THORNED
  static [FigletFont]$THREE_POINT
  static [FigletFont]$THREEPOINT
  static [FigletFont]$TICKS_SLANT
  static [FigletFont]$TICKS
  static [FigletFont]$TICKSSLANT
  static [FigletFont]$TILES
  static [FigletFont]$TINKER_TOY
  static [FigletFont]$TOMBSTONE
  static [FigletFont]$TRAIN
  static [FigletFont]$TREK
  static [FigletFont]$TSALAGI
  static [FigletFont]$TUBES_REGULAR
  static [FigletFont]$TUBES_SMUSHED
  static [FigletFont]$TUBULAR
  static [FigletFont]$TWISTED
  static [FigletFont]$TWO_POINT
  static [FigletFont]$TWOPOINT
  static [FigletFont]$UBLK
  static [FigletFont]$UNIVERS
  static [FigletFont]$USA_FLAG
  static [FigletFont]$USAFLAG
  static [FigletFont]$VARSITY
  static [FigletFont]$WAVY
  static [FigletFont]$WEIRD
  static [FigletFont]$WET_LETTER
  static [FigletFont]$WETLETTER
  static [FigletFont]$WHIMSY
  static [FigletFont]$WOW

  [int]$Height
  [int]$Baseline
  [int]$MaxWidth
  [char]$Hardblank
  [int]$SmushingRules

  FigletFont() { [void]$this.ToDefault() }
  FigletFont([string]$Name) {
    [ValidateNotNullOrWhiteSpace()][string]$Name = $Name
    [void][FigletFont]::From($Name, [ref]$this)
  }
  FigletFont([FigletFontName]$Name) {
    [void][FigletFont]::From($Name, [ref]$this)
  }
  FigletFont([List[FigletCharacter]]$characters, [FigletHeader]$header) {
    $this._characters = [Dictionary[int, FigletCharacter]]::new()
    foreach ($c in $characters) { $this._characters[$c.Code] = $c }
    $this.Height = $header.Height
    $this.Baseline = $header.Baseline
    $this.MaxWidth = $header.MaxLength
    $this.Hardblank = $header.Hardblank

    if ($header.HasFullLayout) {
      $this.SmushingRules = $header.FullLayout -band 63
    } elseif ($header.OldLayout -gt 0) {
      $this.SmushingRules = $header.OldLayout -band 63
    } else {
      $this.SmushingRules = 0
    }
  }
  static [FigletFont] Create() {
    return [FigletFont]::new().ToDefault()
  }
  static [FigletFont] Create([string]$Name) {
    return [FigletFont]::new().To($Name)
  }
  static [FigletFont] Create([FigletFontName]$Name) {
    return [FigletFont]::new().To($Name)
  }
  [FigletFont] ToDefault() {
    return $this.To("STANDARD")
  }
  [FigletFont] To([FigletFontName]$Name) {
    return [FigletFont]::From($Name, [ref]$this)
  }
  static [FigletFont] From([FigletFontName]$Name, [ref]$o) {
    $font_flf = [FigletFont]::GetFontflfPath("$Name")
    $font = $null -ne [FigletFont]::$Name ? [FigletFont]::$Name : [FigletFont]::Load($font_flf)
    if ($o.Value -isnot [FigletFont]) {
      throw "$($o.Value.GetType().FullName) isnot [FigletFont]"
    }
    $o.Value._characters = $font._characters
    $o.Value.Height = $font.Height
    $o.Value.Baseline = $font.Baseline
    $o.Value.MaxWidth = $font.MaxWidth
    $o.Value.Hardblank = $font.Hardblank
    $o.Value.SmushingRules = $font.SmushingRules
    [FigletFont]::$Name = $o.Value
    return $o.Value
  }
  static [FigletFont] Default() {
    if ($null -eq [FigletFont]::STANDARD) {
      [FigletFont]::STANDARD = [FigletFont]::new("STANDARD")
    }
    return [FigletFont]::STANDARD
  }
  static [FigletFont] Load([string]$path) {
    return [FigletFont]::Load([System.IO.FileInfo]::new([PsModuleBase]::GetUnResolvedPath($path)))
  }
  static [FigletFont] Load([System.IO.FileInfo]$file) {
    if (![IO.File]::Exists($file.FullName)) {
      throw [FileNotFoundException]::new("Could not find font '$file'.")
    }
    $ext = $file.Extension.ToLowerInvariant()
    if ($ext -notin @(".flf", ".tlf")) {
      # Write-Host "[DEBUG] NOT A FONT FILE!." -f Yellow
      # skip this file
      return $null
    }
    return [FigletFont]::Parse([IO.File]::ReadAllText($file.FullName))
  }
  static [void] LoadAll() {
    $fonts = [FigletFont]::GetSupportedFontNames()
    foreach ($name in $fonts) {
      [FigletFont]::$name = [FigletFont]::new($name)
    }
  }
  static [string[]] GetSupportedFontNames() {
    [string[]]$names = [Enum]::GetNames([FigletFontName])
    return [FigletFont].GetProperties().Where({
        $_.PropertyType.Name -eq "FigletFont" -and
        $_.Name -in $names -and
        "HiddenAttribute" -notin $_.CustomAttributes.AttributeType.Name
      }
    ).Name
  }

  static [FigletFont] Parse([string]$source) {
    return [FigletFontParser]::Parse($source)
  }

  [int] GetWidth([string]$text) {
    $sum = 0
    foreach ($c in $text.ToCharArray()) {
      $fc = $this.GetCharacter([int][char]$c)
      if ($null -ne $fc) { $sum += $fc.Width }
    }
    return $sum
  }

  [List[FigletCharacter]] GetCharacters([string]$text) {
    $result = [List[FigletCharacter]]::new()
    foreach ($c in $text.ToCharArray()) {
      $fc = $this.GetCharacter([int][char]$c)
      if ($null -ne $fc) { $result.Add($fc) }
    }
    return $result
  }
  static [string] GetFontflfPath([string]$Name) {
    $fonts_in_repo = [IO.DirectoryInfo][IO.Path]::Combine((Resolve-Path .).Path, "Private", "fonts")
    $fonts_in_module_path = [IO.DirectoryInfo][IO.Path]::Combine((Get-InstalledModule cliHelper.core).InstalledLocation, "Private", "fonts")
    $font_flf_path = $(if ($fonts_in_repo.Exists) {
        [IO.Path]::Combine($fonts_in_repo.FullName, "$Name.flf")
      } elseif ($fonts_in_module_path.Exists) {
        [IO.Path]::Combine($fonts_in_module_path.FullName, "$Name.flf")
      } else {
        "$Name.flf"
      }
    )
    if (![File]::Exists($font_flf_path)) {
      throw "Could not find $Name.flf font."
    }
    return $font_flf_path
  }

  hidden [FigletCharacter] GetCharacter([int]$code) {
    $fc = $null
    if ($this._characters.TryGetValue($code, [ref]$fc)) { return $fc }
    return $null
  }
}

# ---------------------------------------------------------------------------
# FigletText  – IRenderable that draws text using a FigletFont
# ---------------------------------------------------------------------------
class FigletText : IRenderable {
  hidden [FigletFont]$_font
  hidden [string]$_text
  static hidden [string]$OverscoreChars = '|/\[]{}()<>'

  [Color]$Color = [Color]::Default        # use Default for "no colour"
  [object]$Justification = $null          # [Justify] or $null for left
  [bool]$Pad = $false
  [FigletLayoutMode]$LayoutMode = [FigletLayoutMode]::FullSize

  FigletText([string]$text) {
    $this._font = [FigletFont]::Default()
    $this._text = if ($null -ne $text) { $text } else { '' }
  }

  FigletText([FigletFont]$font, [string]$text) {
    if ($null -eq $font) { throw [ArgumentNullException]::new('font') }
    $this._font = $font
    $this._text = if ($null -ne $text) { $text } else { '' }
  }

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    $w = $this._font.GetWidth($this._text)
    $safe = [Math]::Min($w, $maxWidth)
    return [Measurement]::new($safe, $safe)
  }

  [Segment[]] Render([RenderOptions]$options, [int]$maxWidth) {
    $fg = if ($null -ne $this.Color -and -not $this.Color.IsDefault) { $this.Color } else { [Color]::Default }
    $style = [Style]::new($fg)
    $alignment = if ($null -ne $this.Justification) { $this.Justification } else { [Justify]::Left }

    $result = [List[Segment]]::new()

    foreach ($row in $this.GetRows($maxWidth)) {
      if ($row.Count -eq 0) { continue }

      # Pre-compute fit/smush junctions between adjacent glyphs
      $junctions = $null
      if ($this.LayoutMode -ne [FigletLayoutMode]::FullSize -and $row.Count -gt 1) {
        $junctions = [object[]]::new($row.Count - 1)
        $smushRules = if ($this.LayoutMode -eq [FigletLayoutMode]::Smushed) { $this._font.SmushingRules } else { 0 }
        for ($i = 0; $i -lt $row.Count - 1; $i++) {
          $junctions[$i] = [FigletText]::ComputeJunction(
            $row[$i], $row[$i + 1], $this.LayoutMode, $smushRules, $this._font.Hardblank)
        }
      }

      for ($lineIdx = 0; $lineIdx -lt $this._font.Height; $lineIdx++) {
        $lineText = if ($null -ne $junctions) {
          [FigletText]::BuildLine($row, $lineIdx, $junctions, $this._font.Hardblank)
        } else {
          $sb = [StringBuilder]::new()
          foreach ($fc in $row) { [void]$sb.Append($fc.Lines[$lineIdx]) }
          $sb.ToString()
        }

        # Replace hardblanks with real spaces
        if ($this._font.Hardblank -ne ' ') {
          $lineText = $lineText.Replace($this._font.Hardblank, ' ')
        }

        $line = [Segment]::new($lineText, $style)
        $lineWidth = $line.CellCount()

        switch ($alignment) {
          ([Justify]::Left) {
            $result.Add($line)
            if ($this.Pad -and $lineWidth -lt $maxWidth) {
              $result.Add([Segment]::Padding($maxWidth - $lineWidth))
            }
            break
          }
          ([Justify]::Center) {
            $left = [Math]::Max(0, [Math]::Floor(($maxWidth - $lineWidth) / 2))
            $right = [Math]::Max(0, $maxWidth - $lineWidth) - $left
            if ($left -gt 0) { $result.Add([Segment]::Padding($left)) }
            $result.Add($line)
            if ($this.Pad -and $right -gt 0) { $result.Add([Segment]::Padding($right)) }
            break
          }
          ([Justify]::Right) {
            if ($lineWidth -lt $maxWidth) { $result.Add([Segment]::Padding($maxWidth - $lineWidth)) }
            $result.Add($line)
            break
          }
        } default {
          throw [NotSupportedException]::new("Invalid alignment mode: $alignment")
        }

        $result.Add([Segment]::LineBreak)
      }
    }

    return $result.ToArray()
  }

  # ---- Internal helpers --------------------------------------------------

  hidden [List[List[FigletCharacter]]] GetRows([int]$maxWidth) {
    $result = [List[List[FigletCharacter]]]::new()
    $words = $this._text -split '(?<=\s)(?=\S)|(?<=\S)(?=\s)' | Where-Object { $_ -ne '' }
    $line = [List[FigletCharacter]]::new()
    $totalWidth = 0

    foreach ($word in $words) {
      $chars = $this._font.GetCharacters($word)
      $width = 0
      foreach ($fc in $chars) { $width += $fc.Width }

      if ($totalWidth + $width -le $maxWidth) {
        $line.AddRange($chars)
        $totalWidth += $width
      } else {
        if ($width -le $maxWidth) {
          if ($line.Count -gt 0) { $result.Add($line) }
          $line = [List[FigletCharacter]]::new($chars)
          $totalWidth = $width
        } else {
          # Word is wider than maxWidth: split character by character
          $queue = [Queue[FigletCharacter]]::new($chars)
          while ($queue.Count -gt 0) {
            $cur = $queue.Dequeue()
            if ($totalWidth + $cur.Width -gt $maxWidth -and $line.Count -gt 0) {
              $result.Add($line)
              $line = [List[FigletCharacter]]::new()
              $totalWidth = 0
            }
            $line.Add($cur)
            $totalWidth += $cur.Width
          }
        }
      }
    }

    if ($line.Count -gt 0) { $result.Add($line) }
    return $result
  }

  static hidden [hashtable] ComputeJunction(
    [FigletCharacter]$left, [FigletCharacter]$right,
    [FigletLayoutMode]$mode, [int]$smushRules, [char]$hardblank) {

    $fit = [int]::MaxValue
    for ($y = 0; $y -lt $left.Height; $y++) {
      $ln = $left.Lines[$y].Replace($hardblank, ' ')
      $rn = $right.Lines[$y].Replace($hardblank, ' ')
      $trailing = $left.Lines[$y].Length - $ln.TrimEnd(' ').Length
      $leading = $right.Lines[$y].Length - $rn.TrimStart(' ').Length
      $fit = [Math]::Min($fit, $trailing + $leading)
    }
    if ($fit -eq [int]::MaxValue) { $fit = 0 }

    # Never fit/smush the space character
    if ($left.Code -eq 32 -or $right.Code -eq 32) {
      return @{ Amount = 0; MergeChars = $null }
    }

    if ($mode -ne [FigletLayoutMode]::Smushed) {
      return @{ Amount = $fit; MergeChars = $null }
    }

    # Try to smush: one extra column with merged boundary chars
    $mergeChars = [char[]]::new($left.Height)
    for ($i = 0; $i -lt $left.Height; $i++) {
      $ll = $left.Lines[$i]; $rl = $right.Lines[$i]
      $trailing = $ll.Length - $ll.Replace($hardblank, ' ').TrimEnd(' ').Length
      $trimFromLeft = [Math]::Min($trailing, $fit)
      $trimFromRight = $fit - $trimFromLeft

      $leftBound = $ll.Length - $trimFromLeft - 1
      $rightBound = $trimFromRight

      $lc = if ($leftBound -ge 0) { $ll[$leftBound] } else { [char]' ' }
      $rc = if ($rightBound -lt $rl.Length) { $rl[$rightBound] } else { [char]' ' }

      if ($lc -eq ' ' -and $rc -eq ' ') { $mergeChars[$i] = ' '; continue }

      $merged = [FigletText]::SmushChars($lc, $rc, $smushRules, $hardblank)
      if ($null -eq $merged) { return @{ Amount = $fit; MergeChars = $null } }
      $mergeChars[$i] = $merged
    }
    return @{ Amount = ($fit + 1); MergeChars = $mergeChars }
  }

  static hidden [object] SmushChars([char]$left, [char]$right, [int]$rules, [char]$hardblank) {
    if ($left -eq ' ' -and $right -eq ' ') { return $null }
    if ($left -eq ' ') { return [object]$right }
    if ($right -eq ' ') { return [object]$left }

    # Hardblank rule (rule 6)
    if ($left -eq $hardblank -and $right -eq $hardblank) {
      return if ($rules -eq 0 -or ($rules -band 32) -ne 0) { [object]$hardblank } else { $null }
    }
    if ($left -eq $hardblank) { $left = ' ' }
    if ($right -eq $hardblank) { $right = ' ' }
    if ($left -eq ' ' -and $right -eq ' ') { return $null }
    if ($left -eq ' ') { return [object]$right }
    if ($right -eq ' ') { return [object]$left }

    # Universal smushing
    if ($rules -eq 0) { return [object]$right }

    # Rule 1: equal chars
    if (($rules -band 1) -ne 0 -and $left -eq $right) { return [object]$left }

    # Rule 2: underscore
    if (($rules -band 2) -ne 0) {
      if ($left -eq '_' -and [FigletText]::OverscoreChars.Contains($right.ToString())) { return [object]$right }
      if ($right -eq '_' -and [FigletText]::OverscoreChars.Contains($left.ToString())) { return [object]$left }
    }

    # Rule 3: hierarchy
    if (($rules -band 4) -ne 0) {
      $lc = [FigletText]::GetHierarchyClass($left)
      $rc = [FigletText]::GetHierarchyClass($right)
      if ($lc -ne 0 -and $rc -ne 0 -and $lc -ne $rc) {
        return if ($lc -gt $rc) { [object]$left } else { [object]$right }
      }
    }

    # Rule 4: opposite pairs
    if (($rules -band 8) -ne 0) {
      $pair = "$left$right"
      if ($pair -in @('[]', '][', '{}', '}{', '()', ')(')) { return [object]([char]'|') }
    }

    # Rule 5: big X
    if (($rules -band 16) -ne 0) {
      if ($left -eq '/' -and $right -eq '\') { return [object]([char]'|') }
      if ($left -eq '\' -and $right -eq '/') { return [object]([char]'Y') }
      if ($left -eq '>' -and $right -eq '<') { return [object]([char]'X') }
    }

    return $null
  }

  static hidden [int] GetHierarchyClass([char]$c) {
    switch ($c) {
      '|' { return 1 }
      { $_ -in '/', '\' } { return 2 }
      { $_ -in '[', ']' } { return 3 }
      { $_ -in '{', '}' } { return 4 }
      { $_ -in '(', ')' } { return 5 }
      { $_ -in '<', '>' } { return 6 }
    }
    return 0
  }

  static hidden [string] BuildLine(
    [List[FigletCharacter]]$row, [int]$lineIdx,
    [object[]]$junctions, [char]$hardblank) {

    if ($row.Count -eq 0) { return '' }

    $sb = [StringBuilder]::new($row[0].Lines[$lineIdx])

    for ($ri = 1; $ri -lt $row.Count; $ri++) {
      $junc = $junctions[$ri - 1]
      $amount = [int]$junc.Amount
      $mergeChars = $junc.MergeChars
      $rightLine = $row[$ri].Lines[$lineIdx]

      # Count trailing spaces/hardblanks in accumulated left side
      $trailing = 0
      for ($k = $sb.Length - 1; $k -ge 0; $k--) {
        if ($sb[$k] -eq ' ' -or $sb[$k] -eq $hardblank) { $trailing++ } else { break }
      }

      if ($null -ne $mergeChars) {
        $fit = $amount - 1
        $trimFromLeft = [Math]::Min($trailing, $fit)
        $trimFromRight = $fit - $trimFromLeft
        $removeLeft = [Math]::Min($trimFromLeft + 1, $sb.Length)
        [void]$sb.Remove($sb.Length - $removeLeft, $removeLeft)
        [void]$sb.Append($mergeChars[$lineIdx])
        $skip = $trimFromRight + 1
        if ($skip -lt $rightLine.Length) { [void]$sb.Append($rightLine.Substring($skip)) }
      } else {
        $trimFromLeft = [Math]::Min($trailing, $amount)
        $trimFromRight = $amount - $trimFromLeft
        if ($trimFromLeft -gt 0) { [void]$sb.Remove($sb.Length - $trimFromLeft, $trimFromLeft) }
        if ($trimFromRight -gt 0 -and $trimFromRight -lt $rightLine.Length) {
          [void]$sb.Append($rightLine.Substring($trimFromRight))
        } else {
          [void]$sb.Append($rightLine)
        }
      }
    }

    return $sb.ToString()
  }
}
