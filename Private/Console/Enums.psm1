enum VerticalAlignment {
  Top = 0
  Middle = 1
  Bottom = 2
}
enum VerticalOverflow {
  Crop = 0
  Ellipsis = 1
  Visible = 2
}
enum VerticalOverflowCropping {
  Top = 0
  Bottom = 1
}

enum InteractionSupport {
  Detect = 0
  Yes = 1
  No = 2
}

enum CursorDirection {
  Up = 0
  Down = 1
  Left = 2
  Right = 3
}

enum Justify {
  Left = 0
  Right = 1
  Center = 2
}
enum Overflow {
  Fold = 0
  Crop = 1
  Ellipsis = 2
}

enum HorizontalAlignment {
  Left = 0
  Center = 1
  Right = 2
}

enum JsonTokenType {
  None = 0
  ObjectStart = 1
  ObjectEnd = 2
  ArrayStart = 3
  ArrayEnd = 4
  MemberName = 5
  String = 6
  Number = 7
  Boolean = 8
  Null = 9
  Comment = 10
  Symbol = 11
}

[Flags()]
enum Decoration {
  None = 0
  Bold = 1
  Dim = 2
  Italic = 4
  Underline = 8
  Invert = 16
  Conceal = 32
  SlowBlink = 64
  RapidBlink = 128
  Strikethrough = 256
}

$MemberDefinition = @{
  TypeName   = 'Decoration'
  MemberName = 'GetFlags'
  MemberType = 'ScriptMethod'
  Value      = {
    foreach ($Flag in $this.GetType().GetEnumValues()) {
      if ($this.HasFlag($Flag)) { $Flag }
    }
  }
}
Update-TypeData @MemberDefinition -Force
# $dec = [Decoration]28
# $dec.GetFlags()

enum ColorSystemSupport {
  Detect = -1
  NoColors = 0
  Legacy = 1
  Standard = 2
  EightBit = 3
  TrueColor = 4
}

enum ColorSystem {
  NoColors = 0
  Legacy = 1
  Standard = 2
  EightBit = 3
  TrueColor = 4
}

enum AnsiSupport {
  Detect = 0
  Yes = 1
  No = 2
}

enum ListPromptInputResult {
}

enum BoxBorderPart {
  HeaderTopLeft = 0
  HeaderTop = 1
  HeaderTopRight = 2
  HeaderRight = 3
  HeaderBottomRight = 4
  HeaderBottom = 5
  HeaderBottomLeft = 6
  HeaderLeft = 7
  TopLeft = 8
  Top = 9
  TopRight = 10
  Right = 11
  BottomRight = 12
  Bottom = 13
  BottomLeft = 14
  Left = 15
}
enum TableBorderPart {
  HeaderTopLeft = 0
  HeaderTop = 1
  HeaderTopSeparator = 2
  HeaderTopRight = 3
  HeaderLeft = 4
  HeaderSeparator = 5
  HeaderRight = 6
  HeaderBottomLeft = 7
  HeaderBottom = 8
  HeaderBottomSeparator = 9
  HeaderBottomRight = 10
  CellLeft = 11
  CellSeparator = 12
  CellRight = 13
  FooterTopLeft = 14
  FooterTop = 15
  FooterTopSeparator = 16
  FooterTopRight = 17
  FooterBottomLeft = 18
  FooterBottom = 19
  FooterBottomSeparator = 20
  FooterBottomRight = 21
  RowLeft = 22
  RowCenter = 23
  RowSeparator = 24
  RowRight = 25
}

enum TreeGuidePart {
  Space = 0
  Continue = 1
  Fork = 2
  End = 3
}

enum TreePart {
  Root = 0
  Leaf = 1
}

enum TablePart {
  Top = 0
  HeaderSeparator = 1
  RowSeparator = 2
  FooterSeparator = 3
  Bottom = 4
}

enum FigletLayoutMode {
  FullSize = 0
  Fitted = 1
  Smushed = 2
}

enum FigletFontName {
  ACROBATIC
  ALLIGATOR
  ALLIGATOR2
  ALLIGATOR3
  ALPHA
  ALPHABET
  AMC_3_LINE
  AMC_3_LIV1
  AMC_AAA01
  AMC_NEKO
  AMC_RAZOR
  AMC_RAZOR2
  AMC_SLASH
  AMC_SLIDER
  AMC_THIN
  AMC_TUBES
  AMC_UNTITLED
  AMC3LINE
  AMC3LIV1
  AMCAAA01
  AMCNEKO
  AMCRAZO2
  AMCRAZOR
  AMCSLASH
  AMCSLDER
  AMCTHIN
  AMCTUBES
  AMCUN1
  ANSI_REGULAR
  ANSI_SHADOW
  ARROWS
  ASCII_3D
  ASCII_NEW_ROMAN_2
  ASCII_NEW_ROMAN
  AVATAR
  B1FF
  BANNER
  BANNER3_D
  BANNER3
  BANNER4
  BARBWIRE
  BASIC
  BEAR
  BELL
  BENJAMIN
  BIG_CHIEF
  BIG_MONEY_NE
  BIG_MONEY_NW
  BIG_MONEY_SE
  BIG_MONEY_SW
  BIG
  BIGCHIEF
  BIGFIG
  BINARY
  BLOCK
  BLOCKS
  BLOODY
  BOLGER
  BRACED
  BRIGHT
  BROADWAY_KB_2
  BROADWAY_KB
  BROADWAY
  BUBBLE
  BULBHEAD
  CALGPHY2
  CALIGRAPHY
  CALIGRAPHY2
  CALVIN_S
  CARDS
  CATWALK
  CHISELED
  CHUNKY
  COINSTAK
  COLA
  COLOSSAL
  COMPUTER
  CONTESSA
  CONTRAST
  COSMIC
  COSMIKE
  CRAWFORD
  CRAWFORD2
  CRAZY
  CRICKET
  CURSIVE
  CYBERLARGE
  CYBERMEDIUM
  CYBERSMALL
  CYGNET
  DANC4
  DANCING_FONT
  DANCINGFONT
  DECIMAL
  DEF_LEPPARD
  DEFAULT_3D
  DEFLEPPARD
  DELTA_CORPS_PRIEST_1
  DIAGONAL_3D_2
  DIAGONAL_3D
  DIAMOND
  DIET_COLA
  DIETCOLA
  DIGITAL
  DOH
  DOOM
  DOS_REBEL
  DOSREBEL
  DOT_MATRIX
  DOTMATRIX
  DOUBLE_SHORTS
  DOUBLE
  DOUBLESHORTS
  DR_PEPPER
  DRPEPPER
  DWHISTLED
  EFTI_CHESS
  EFTI_FONT
  EFTI_ITALIC
  EFTI_PITI
  EFTI_ROBOT
  EFTI_WALL
  EFTI_WATER
  EFTICHESS
  EFTIFONT
  EFTIPITI
  EFTIROBOT
  EFTITALIC
  EFTIWALL
  EFTIWATER
  ELECTRONIC
  ELITE
  EPIC
  FENDER
  FILTER_1
  FIRE_FONT_K
  FIRE_FONT_S
  FLIPPED
  FLOWER_POWER
  FLOWERPOWER
  FOUR_MAX
  FOUR_TOPS
  FOURTOPS
  FRAKTUR
  FUN_FACE
  FUN_FACES
  FUNFACE
  FUNFACES
  FUZZY
  GEORGI16
  GEORGIA11
  GHOST
  GHOULISH
  GLENYN
  GOOFY
  GOTHIC
  GRACEFUL
  GRADIENT
  GRAFFITI
  GREEK
  HALFIWI
  HEART_LEFT
  HEART_RIGHT
  HENRY_3D
  HENRY3D
  HEX
  HIEROGLYPHS
  HOLLYWOOD
  HORIZONTAL_LEFT
  HORIZONTAL_RIGHT
  HORIZONTALLEFT
  HORIZONTALRIGHT
  ICL_1900
  IMPOSSIBLE
  INVITA
  ISOMETRIC1
  ISOMETRIC2
  ISOMETRIC3
  ISOMETRIC4
  ITALIC
  IVRIT
  JACKY
  JAZMINE
  JERUSALEM
  JS_BLOCK_LETTERS
  JS_BRACKET_LETTERS
  JS_CAPITAL_CURVES
  JS_CURSIVE
  JS_STICK_LETTERS
  KATAKANA
  KBAN
  KEYBOARD
  KNOB
  KOHOLINT
  KOMPAKTBLK
  KONTO_SLANT
  KONTO
  KONTOSLANT
  LARRY_3D_2
  LARRY_3D
  LARRY3D
  LCD
  LEAN
  LETTERS
  LIL_DEVIL
  LILDEVIL
  LINE_BLOCKS
  LINEBLOCKS
  LINES_3D
  LINUX
  LOCKERGNOME
  MADRID
  MARQUEE
  MAXFOUR
  MAXIWI
  MERLIN1
  MERLIN2
  MIKE
  MINI
  MINIWI
  MIRROR
  MNEMONIC
  MODULAR
  MONO9
  MORSE
  MORSE2
  MOSCOW
  MSHEBREW210
  MUZZLE
  NANCYJ_FANCY
  NANCYJ_IMPROVED
  NANCYJ_UNDERLINED
  NANCYJ
  NIPPLES
  NSCRIPT
  NT_GREEK
  NTGREEK
  NV_SCRIPT
  O8
  OBLIQUE_5LINE_2
  OBLIQUE_5LINE
  OCTAL
  OGRE
  OLD_BANNER
  OLDBANNER
  ONE_ROW
  OS2
  PATORJK_HEX
  PATORJKS_CHEESE
  PAWP
  PEAKS_SLANT
  PEAKS
  PEAKSSLANT
  PEBBLES
  PEPPER
  PIXEL_3X5
  POISON
  PUFFY
  PUZZLE
  PYRAMID
  RAMMSTEIN
  README
  RECTANGLES
  RED_PHOENIX
  RELIEF
  RELIEF2
  REV
  REVERSE
  ROMAN
  ROT13
  ROTATED
  ROUNDED
  ROWAN_CAP
  ROWANCAP
  ROZZO
  RUNIC
  RUNYC
  S_BLOOD
  S_RELIEF
  SANTA_CLARA
  SANTACLARA
  SBLOOD
  SCRIPT
  SERIFCAP
  SHADOW
  SHIMROD
  SHORT
  SIX_FO
  SL_SCRIPT
  SLANT_RELIEF
  SLANT
  SLIDE
  SLSCRIPT
  SMALL_CAPS
  SMALL_ISOMETRIC1
  SMALL_KEYBOARD
  SMALL_POISON
  SMALL_SCRIPT
  SMALL_SHADOW
  SMALL_SLANT
  SMALL_TENGWAR
  SMALL
  SMALLCAPS
  SMISOME1
  SMKEYBOARD
  SMPOISON
  SMSCRIPT
  SMSHADOW
  SMSLANT
  SMTENGWAR
  SOFT
  SPEED
  SPLIFF
  STACEY
  STAMPATE
  STAMPATELLO
  STANDARD
  STAR_STRIPS
  STAR_WARS
  STARSTRIPS
  STARWARS
  STELLAR
  STENCIL
  STFOREK
  STICK_LETTERS
  STOP
  STRAIGHT
  STRONGER_THAN_ALL
  SUB_ZERO
  SWAMP_LAND
  SWAMPLAND
  SWAN
  SWEET
  TANJA
  TENGWAR
  TERM
  TERMINUS_DOTS
  TERMINUS
  TEST1
  THE_EDGE
  THICK
  THIN
  THIS
  THORNED
  THREE_POINT
  THREEPOINT
  TICKS_SLANT
  TICKS
  TICKSSLANT
  TILES
  TINKER_TOY
  TOMBSTONE
  TRAIN
  TREK
  TSALAGI
  TUBES_REGULAR
  TUBES_SMUSHED
  TUBULAR
  TWISTED
  TWO_POINT
  TWOPOINT
  UBLK
  UNIVERS
  USA_FLAG
  USAFLAG
  VARSITY
  WAVY
  WEIRD
  WET_LETTER
  WETLETTER
  WHIMSY
  WOW
}

# Core Abstractions
class Measurement {
  [int]$Min
  [int]$Max
  Measurement([int]$min, [int]$max) {
    $this.Min = $min
    $this.Max = $max
  }
}

class RenderOptions {
  [ColorSystem]$ColorSystem
  [bool]$Ansi
  [bool]$SingleLine
  [Nullable[int]]$Height
  [Nullable[Justify]]$Justification
  [bool]$Unicode

  RenderOptions() {
    $this.ColorSystem = [ColorSystem]::NoColors
    $this.Ansi = $false
    $this.SingleLine = $false
    $this.Height = $null
    $this.Justification = $null
    $this.Unicode = $true
  }

  static [RenderOptions] Create([object]$writer, [object]$capabilities) {
    $options = [RenderOptions]::new()
    if ($null -ne $capabilities) {
      $options.ColorSystem = $capabilities.ColorSystem
      $options.Ansi = $capabilities.Ansi
    }
    return $options
  }
}

class IRenderable {
  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    $safeWidth = [Math]::Max(0, $maxWidth)
    return [Measurement]::new($safeWidth, $safeWidth)
  }

  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    return [object[]]@()
  }
}

class IAnsiConsoleCursor {

}
class IAnsiConsoleInput {

}
class IExclusivityMode {

}

class IAnsiConsole {
  [object]$Profile
  [IAnsiConsoleCursor]$Cursor
  [IAnsiConsoleInput]$Input
  [IExclusivityMode]$ExclusivityMode
  [object] GetWriter() { return $null }
  [void] Clear() { $this.Clear($true) }
  [void] Clear([bool]$_Home) {}
  [void] Write([IRenderable]$renderable) {
  }
  [void] WriteAnsi([object]$action) {
    # Action[AnsiWriter]
  }
}
