using namespace System

class Spinner {
  [string]$Name
  [TimeSpan]$Interval
  [bool]$IsUnicode
  [string[]]$Frames

  static [Spinner]$Default
  static [Spinner]$Ascii
  static [Spinner]$Dots
  static [Spinner]$Dots2
  static [Spinner]$Dots3
  static [Spinner]$Dots4
  static [Spinner]$Dots5
  static [Spinner]$Dots6
  static [Spinner]$Dots7
  static [Spinner]$Dots8
  static [Spinner]$Dots9
  static [Spinner]$Dots10
  static [Spinner]$Dots11
  static [Spinner]$Dots12
  static [Spinner]$Dots13
  static [Spinner]$Dots14
  static [Spinner]$Dots8Bit
  static [Spinner]$DotsCircle
  static [Spinner]$Sand
  static [Spinner]$Line
  static [Spinner]$Line2
  static [Spinner]$Pipe
  static [Spinner]$SimpleDots
  static [Spinner]$SimpleDotsScrolling
  static [Spinner]$Star
  static [Spinner]$Star2
  static [Spinner]$Flip
  static [Spinner]$Hamburger
  static [Spinner]$GrowVertical
  static [Spinner]$GrowHorizontal
  static [Spinner]$Balloon
  static [Spinner]$Balloon2
  static [Spinner]$Noise
  static [Spinner]$Bounce
  static [Spinner]$BoxBounce
  static [Spinner]$BoxBounce2
  static [Spinner]$Triangle
  static [Spinner]$Binary
  static [Spinner]$Arc
  static [Spinner]$Circle
  static [Spinner]$SquareCorners
  static [Spinner]$CircleQuarters
  static [Spinner]$CircleHalves
  static [Spinner]$Squish
  static [Spinner]$Toggle
  static [Spinner]$Toggle2
  static [Spinner]$Toggle3
  static [Spinner]$Toggle4
  static [Spinner]$Toggle5
  static [Spinner]$Toggle6
  static [Spinner]$Toggle7
  static [Spinner]$Toggle8
  static [Spinner]$Toggle9
  static [Spinner]$Toggle10
  static [Spinner]$Toggle11
  static [Spinner]$Toggle12
  static [Spinner]$Toggle13
  static [Spinner]$Arrow
  static [Spinner]$Arrow2
  static [Spinner]$Arrow3
  static [Spinner]$BouncingBar
  static [Spinner]$BouncingBall
  static [Spinner]$Smiley
  static [Spinner]$Monkey
  static [Spinner]$Hearts
  static [Spinner]$Clock
  static [Spinner]$Earth
  static [Spinner]$Material
  static [Spinner]$Moon
  static [Spinner]$Runner
  static [Spinner]$Pong
  static [Spinner]$Shark
  static [Spinner]$Dqpb
  static [Spinner]$Weather
  static [Spinner]$Christmas
  static [Spinner]$Grenade
  static [Spinner]$Point
  static [Spinner]$Layer
  static [Spinner]$BetaWave
  static [Spinner]$FingerDance
  static [Spinner]$FistBump
  static [Spinner]$SoccerHeader
  static [Spinner]$Mindblown
  static [Spinner]$Speaker
  static [Spinner]$OrangePulse
  static [Spinner]$BluePulse
  static [Spinner]$OrangeBluePulse
  static [Spinner]$TimeTravel
  static [Spinner]$Aesthetic
  static [Spinner]$DwarfFortress

  Spinner([string]$Name) {
    switch ($Name) {
      'Ascii' {
        $this.Name = 'Ascii';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('-', '\\', '|', '/', '-', '\\', '|', '/')
        break
      }
      'Dots' {
        $this.Name = 'Dots';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
        break
      }
      'Dots2' {
        $this.Name = 'Dots2';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⣾', '⣽', '⣻', '⢿', '⡿', '⣟', '⣯', '⣷')
        break
      }
      'Dots3' {
        $this.Name = 'Dots3';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⠋', '⠙', '⠚', '⠞', '⠖', '⠦', '⠴', '⠲', '⠳', '⠓')
        break
      }
      'Dots4' {
        $this.Name = 'Dots4';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⠄', '⠆', '⠇', '⠋', '⠙', '⠸', '⠰', '⠠', '⠰', '⠸', '⠙', '⠋', '⠇', '⠆')
        break
      }
      'Dots5' {
        $this.Name = 'Dots5';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⠋', '⠙', '⠚', '⠒', '⠂', '⠂', '⠒', '⠲', '⠴', '⠦', '⠖', '⠒', '⠐', '⠐', '⠒', '⠓', '⠋')
        break
      }
      'Dots6' {
        $this.Name = 'Dots6';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⠁', '⠉', '⠙', '⠚', '⠒', '⠂', '⠂', '⠒', '⠲', '⠴', '⠤', '⠄', '⠄', '⠤', '⠴', '⠲', '⠒', '⠂', '⠂', '⠒', '⠚', '⠙', '⠉', '⠁')
        break
      }
      'Dots7' {
        $this.Name = 'Dots7';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⠈', '⠉', '⠋', '⠓', '⠒', '⠐', '⠐', '⠒', '⠖', '⠦', '⠤', '⠠', '⠠', '⠤', '⠦', '⠖', '⠒', '⠐', '⠐', '⠒', '⠓', '⠋', '⠉', '⠈')
        break
      }
      'Dots8' {
        $this.Name = 'Dots8';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⠁', '⠁', '⠉', '⠙', '⠚', '⠒', '⠂', '⠂', '⠒', '⠲', '⠴', '⠤', '⠄', '⠄', '⠤', '⠠', '⠠', '⠤', '⠦', '⠖', '⠒', '⠐', '⠐', '⠒', '⠓', '⠋', '⠉', '⠈', '⠈')
        break
      }
      'Dots9' {
        $this.Name = 'Dots9';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⢹', '⢺', '⢼', '⣸', '⣇', '⡧', '⡗', '⡏')
        break
      }
      'Dots10' {
        $this.Name = 'Dots10';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⢄', '⢂', '⢁', '⡁', '⡈', '⡐', '⡠')
        break
      }
      'Dots11' {
        $this.Name = 'Dots11';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('⠁', '⠂', '⠄', '⡀', '⢀', '⠠', '⠐', '⠈')
        break
      }
      'Dots12' {
        $this.Name = 'Dots12';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⢀⠀', '⡀⠀', '⠄⠀', '⢂⠀', '⡂⠀', '⠅⠀', '⢃⠀', '⡃⠀', '⠍⠀', '⢋⠀', '⡋⠀', '⠍⠁', '⢋⠁', '⡋⠁', '⠍⠉', '⠋⠉', '⠋⠉', '⠉⠙', '⠉⠙', '⠉⠩', '⠈⢙', '⠈⡙', '⢈⠩', '⡀⢙', '⠄⡙', '⢂⠩', '⡂⢘', '⠅⡘', '⢃⠨', '⡃⢐', '⠍⡐', '⢋⠠', '⡋⢀', '⠍⡁', '⢋⠁', '⡋⠁', '⠍⠉', '⠋⠉', '⠋⠉', '⠉⠙', '⠉⠙', '⠉⠩', '⠈⢙', '⠈⡙', '⠈⠩', '⠀⢙', '⠀⡙', '⠀⠩', '⠀⢘', '⠀⡘', '⠀⠨', '⠀⢐', '⠀⡐', '⠀⠠', '⠀⢀', '⠀⡀')
        break
      }
      'Dots13' {
        $this.Name = 'Dots13';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⣼', '⣹', '⢻', '⠿', '⡟', '⣏', '⣧', '⣶')
        break
      }
      'Dots14' {
        $this.Name = 'Dots14';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⠉⠉', '⠈⠙', '⠀⠹', '⠀⢸', '⠀⣰', '⢀⣠', '⣀⣀', '⣄⡀', '⣆⠀', '⡇⠀', '⠏⠀', '⠋⠁')
        break
      }
      'Dots8Bit' {
        $this.Name = 'Dots8Bit';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⠀', '⠁', '⠂', '⠃', '⠄', '⠅', '⠆', '⠇', '⡀', '⡁', '⡂', '⡃', '⡄', '⡅', '⡆', '⡇', '⠈', '⠉', '⠊', '⠋', '⠌', '⠍', '⠎', '⠏', '⡈', '⡉', '⡊', '⡋', '⡌', '⡍', '⡎', '⡏', '⠐', '⠑', '⠒', '⠓', '⠔', '⠕', '⠖', '⠗', '⡐', '⡑', '⡒', '⡓', '⡔', '⡕', '⡖', '⡗', '⠘', '⠙', '⠚', '⠛', '⠜', '⠝', '⠞', '⠟', '⡘', '⡙', '⡚', '⡛', '⡜', '⡝', '⡞', '⡟', '⠠', '⠡', '⠢', '⠣', '⠤', '⠥', '⠦', '⠧', '⡠', '⡡', '⡢', '⡣', '⡤', '⡥', '⡦', '⡧', '⠨', '⠩', '⠪', '⠫', '⠬', '⠭', '⠮', '⠯', '⡨', '⡩', '⡪', '⡫', '⡬', '⡭', '⡮', '⡯', '⠰', '⠱', '⠲', '⠳', '⠴', '⠵', '⠶', '⠷', '⡰', '⡱', '⡲', '⡳', '⡴', '⡵', '⡶', '⡷', '⠸', '⠹', '⠺', '⠻', '⠼', '⠽', '⠾', '⠿', '⡸', '⡹', '⡺', '⡻', '⡼', '⡽', '⡾', '⡿', '⢀', '⢁', '⢂', '⢃', '⢄', '⢅', '⢆', '⢇', '⣀', '⣁', '⣂', '⣃', '⣄', '⣅', '⣆', '⣇', '⢈', '⢉', '⢊', '⢋', '⢌', '⢍', '⢎', '⢏', '⣈', '⣉', '⣊', '⣋', '⣌', '⣍', '⣎', '⣏', '⢐', '⢑', '⢒', '⢓', '⢔', '⢕', '⢖', '⢗', '⣐', '⣑', '⣒', '⣓', '⣔', '⣕', '⣖', '⣗', '⢘', '⢙', '⢚', '⢛', '⢜', '⢝', '⢞', '⢟', '⣘', '⣙', '⣚', '⣛', '⣜', '⣝', '⣞', '⣟', '⢠', '⢡', '⢢', '⢣', '⢤', '⢥', '⢦', '⢧', '⣠', '⣡', '⣢', '⣣', '⣤', '⣥', '⣦', '⣧', '⢨', '⢩', '⢪', '⢫', '⢬', '⢭', '⢮', '⢯', '⣨', '⣩', '⣪', '⣫', '⣬', '⣭', '⣮', '⣯', '⢰', '⢱', '⢲', '⢳', '⢴', '⢵', '⢶', '⢷', '⣰', '⣱', '⣲', '⣳', '⣴', '⣵', '⣶', '⣷', '⢸', '⢹', '⢺', '⢻', '⢼', '⢽', '⢾', '⢿', '⣸', '⣹', '⣺', '⣻', '⣼', '⣽', '⣾', '⣿')
        break
      }
      'DotsCircle' {
        $this.Name = 'DotsCircle';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⢎ ', '⠎⠁', '⠊⠑', '⠈⠱', ' ⡱', '⢀⡰', '⢄⡠', '⢆⡀')
        break
      }
      'Sand' {
        $this.Name = 'Sand';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⠁', '⠂', '⠄', '⡀', '⡈', '⡐', '⡠', '⣀', '⣁', '⣂', '⣄', '⣌', '⣔', '⣤', '⣥', '⣦', '⣮', '⣶', '⣷', '⣿', '⡿', '⠿', '⢟', '⠟', '⡛', '⠛', '⠫', '⢋', '⠋', '⠍', '⡉', '⠉', '⠑', '⠡', '⢁')
        break
      }
      'Line' {
        $this.Name = 'Line';
        $this.Interval = [TimeSpan]::FromMilliseconds(130);
        $this.IsUnicode = $false;
        $this.Frames = @('-', '\\', '|', '/')
        break
      }
      'Line2' {
        $this.Name = 'Line2';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $false;
        $this.Frames = @('⠂', '-', '–', '—', '–', '-')
        break
      }
      'Pipe' {
        $this.Name = 'Pipe';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $false;
        $this.Frames = @('┤', '┘', '┴', '└', '├', '┌', '┬', '┐')
        break
      }
      'SimpleDots' {
        $this.Name = 'SimpleDots';
        $this.Interval = [TimeSpan]::FromMilliseconds(400);
        $this.IsUnicode = $false;
        $this.Frames = @('.  ', '.. ', '...', '   ')
        break
      }
      'SimpleDotsScrolling' {
        $this.Name = 'SimpleDotsScrolling';
        $this.Interval = [TimeSpan]::FromMilliseconds(200);
        $this.IsUnicode = $false;
        $this.Frames = @('.  ', '.. ', '...', ' ..', '  .', '   ')
        break
      }
      'Star' {
        $this.Name = 'Star';
        $this.Interval = [TimeSpan]::FromMilliseconds(70);
        $this.IsUnicode = $true;
        $this.Frames = @('✶', '✸', '✹', '✺', '✹', '✷')
        break
      }
      'Star2' {
        $this.Name = 'Star2';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $false;
        $this.Frames = @('+', 'x', '*')
        break
      }
      'Flip' {
        $this.Name = 'Flip';
        $this.Interval = [TimeSpan]::FromMilliseconds(70);
        $this.IsUnicode = $false;
        $this.Frames = @('_', '_', '_', '-', '`', '`', '''', '´', '-', '_', '_', '_')
        break
      }
      'Hamburger' {
        $this.Name = 'Hamburger';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('☱', '☲', '☴')
        break
      }
      'GrowVertical' {
        $this.Name = 'GrowVertical';
        $this.Interval = [TimeSpan]::FromMilliseconds(120);
        $this.IsUnicode = $true;
        $this.Frames = @('▁', '▃', '▄', '▅', '▆', '▇', '▆', '▅', '▄', '▃')
        break
      }
      'GrowHorizontal' {
        $this.Name = 'GrowHorizontal';
        $this.Interval = [TimeSpan]::FromMilliseconds(120);
        $this.IsUnicode = $true;
        $this.Frames = @('▏', '▎', '▍', '▌', '▋', '▊', '▉', '▊', '▋', '▌', '▍', '▎')
        break
      }
      'Balloon' {
        $this.Name = 'Balloon';
        $this.Interval = [TimeSpan]::FromMilliseconds(140);
        $this.IsUnicode = $false;
        $this.Frames = @(' ', '.', 'o', 'O', '@', '*', ' ')
        break
      }
      'Balloon2' {
        $this.Name = 'Balloon2';
        $this.Interval = [TimeSpan]::FromMilliseconds(120);
        $this.IsUnicode = $false;
        $this.Frames = @('.', 'o', 'O', '°', 'O', 'o', '.')
        break
      }
      'Noise' {
        $this.Name = 'Noise';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('▓', '▒', '░')
        break
      }
      'Bounce' {
        $this.Name = 'Bounce';
        $this.Interval = [TimeSpan]::FromMilliseconds(120);
        $this.IsUnicode = $true;
        $this.Frames = @('⠁', '⠂', '⠄', '⠂')
        break
      }
      'BoxBounce' {
        $this.Name = 'BoxBounce';
        $this.Interval = [TimeSpan]::FromMilliseconds(120);
        $this.IsUnicode = $true;
        $this.Frames = @('▖', '▘', '▝', '▗')
        break
      }
      'BoxBounce2' {
        $this.Name = 'BoxBounce2';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('▌', '▀', '▐', '▄')
        break
      }
      'Triangle' {
        $this.Name = 'Triangle';
        $this.Interval = [TimeSpan]::FromMilliseconds(50);
        $this.IsUnicode = $true;
        $this.Frames = @('◢', '◣', '◤', '◥')
        break
      }
      'Binary' {
        $this.Name = 'Binary';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $false;
        $this.Frames = @('010010', '001100', '100101', '111010', '111101', '010111', '101011', '111000', '110011', '110101')
        break
      }
      'Arc' {
        $this.Name = 'Arc';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('◜', '◠', '◝', '◞', '◡', '◟')
        break
      }
      'Circle' {
        $this.Name = 'Circle';
        $this.Interval = [TimeSpan]::FromMilliseconds(120);
        $this.IsUnicode = $true;
        $this.Frames = @('◡', '⊙', '◠')
        break
      }
      'SquareCorners' {
        $this.Name = 'SquareCorners';
        $this.Interval = [TimeSpan]::FromMilliseconds(180);
        $this.IsUnicode = $true;
        $this.Frames = @('◰', '◳', '◲', '◱')
        break
      }
      'CircleQuarters' {
        $this.Name = 'CircleQuarters';
        $this.Interval = [TimeSpan]::FromMilliseconds(120);
        $this.IsUnicode = $true;
        $this.Frames = @('◴', '◷', '◶', '◵')
        break
      }
      'CircleHalves' {
        $this.Name = 'CircleHalves'; $this.Interval = [TimeSpan]::FromMilliseconds(50); $this.IsUnicode = $true; $this.Frames = @('◐', '◓', '◑', '◒')
        break
      }
      'Squish' {
        $this.Name = 'Squish';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('╫', '╪')
        break
      }
      'Toggle' {
        $this.Name = 'Toggle';
        $this.Interval = [TimeSpan]::FromMilliseconds(250);
        $this.IsUnicode = $true;
        $this.Frames = @('⊶', '⊷')
        break
      }
      'Toggle2' {
        $this.Name = 'Toggle2';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('▫', '▪')
        break
      }
      'Toggle3' {
        $this.Name = 'Toggle3';
        $this.Interval = [TimeSpan]::FromMilliseconds(120);
        $this.IsUnicode = $true;
        $this.Frames = @('□', '■')
        break
      }
      'Toggle4' {
        $this.Name = 'Toggle4';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('■', '□', '▪', '▫')
        break
      }
      'Toggle5' {
        $this.Name = 'Toggle5';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('▮', '▯')
        break
      }
      'Toggle6' {
        $this.Name = 'Toggle6';
        $this.Interval = [TimeSpan]::FromMilliseconds(300);
        $this.IsUnicode = $true;
        $this.Frames = @('ဝ', '၀')
        break
      }
      'Toggle7' {
        $this.Name = 'Toggle7'; $this.Interval = [TimeSpan]::FromMilliseconds(80); $this.IsUnicode = $true; $this.Frames = @('⦾', '⦿')
        break
      }
      'Toggle8' {
        $this.Name = 'Toggle8';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('◍', '◌')
        break
      }
      'Toggle9' {
        $this.Name = 'Toggle9';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('◉', '◎')
        break
      }
      'Toggle10' {
        $this.Name = 'Toggle10';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('㊂', '㊀', '㊁')
        break
      }
      'Toggle11' {
        $this.Name = 'Toggle11';
        $this.Interval = [TimeSpan]::FromMilliseconds(50);
        $this.IsUnicode = $true;
        $this.Frames = @('⧇', '⧆')
        break
      }
      'Toggle12' {
        $this.Name = 'Toggle12';
        $this.Interval = [TimeSpan]::FromMilliseconds(120);
        $this.IsUnicode = $true;
        $this.Frames = @('☗', '☖')
        break
      }
      'Toggle13' {
        $this.Name = 'Toggle13';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $false;
        $this.Frames = @('=', '*', '-')
        break
      }
      'Arrow' {
        $this.Name = 'Arrow';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('←', '↖', '↑', '↗', '→', '↘', '↓', '↙')
        break
      }
      'Arrow2' {
        $this.Name = 'Arrow2';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('⬆️ ', '↗️ ', '➡️ ', '↘️ ', '⬇️ ', '↙️ ', '⬅️ ', '↖️ ')
        break
      }
      'Arrow3' {
        $this.Name = 'Arrow3';
        $this.Interval = [TimeSpan]::FromMilliseconds(120);
        $this.IsUnicode = $true;
        $this.Frames = @('▹▹▹▹▹', '▸▹▹▹▹', '▹▸▹▹▹', '▹▹▸▹▹', '▹▹▹▸▹', '▹▹▹▹▸')
        break
      }
      'BouncingBar' {
        $this.Name = 'BouncingBar';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('[    ]', '[=   ]', '[==  ]', '[=== ]', '[====]', '[ ===]', '[  ==]', '[   =]', '[    ]', '[   =]', '[  ==]', '[ ===]', '[====]', '[=== ]', '[==  ]', '[=   ]')
        break
      }
      'BouncingBall' {
        $this.Name = 'BouncingBall';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('( ●    )', '(  ●   )', '(   ●  )', '(    ● )', '(     ●)', '(    ● )', '(   ●  )', '(  ●   )', '( ●    )', '(●     )')
        break
      }
      'Smiley' {
        $this.Name = 'Smiley';
        $this.Interval = [TimeSpan]::FromMilliseconds(200);
        $this.IsUnicode = $true;
        $this.Frames = @('😄 ', '😝 ')
        break
      }
      'Monkey' {
        $this.Name = 'Monkey';
        $this.Interval = [TimeSpan]::FromMilliseconds(300);
        $this.IsUnicode = $true;
        $this.Frames = @('🙈 ', '🙈 ', '🙉 ', '🙊 ')
        break
      }
      'Hearts' {
        $this.Name = 'Hearts';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('💛 ', '💙 ', '💜 ', '💚 ', '❤️ ')
        break
      }
      'Clock' {
        $this.Name = 'Clock';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('🕛 ', '🕐 ', '🕑 ', '🕒 ', '🕓 ', '🕔 ', '🕕 ', '🕖 ', '🕗 ', '🕘 ', '🕙 ', '🕚 ')
        break
      }
      'Earth' {
        $this.Name = 'Earth';
        $this.Interval = [TimeSpan]::FromMilliseconds(180);
        $this.IsUnicode = $true;
        $this.Frames = @('🌍 ', '🌎 ', '🌏 ')
        break
      }
      'Material' {
        $this.Name = 'Material';
        $this.Interval = [TimeSpan]::FromMilliseconds(17);
        $this.IsUnicode = $true;
        $this.Frames = @('█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁', '██▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁', '███▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁', '████▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁', '██████▁▁▁▁▁▁▁▁▁▁▁▁▁▁', '██████▁▁▁▁▁▁▁▁▁▁▁▁▁▁', '███████▁▁▁▁▁▁▁▁▁▁▁▁▁', '████████▁▁▁▁▁▁▁▁▁▁▁▁', '█████████▁▁▁▁▁▁▁▁▁▁▁', '█████████▁▁▁▁▁▁▁▁▁▁▁', '██████████▁▁▁▁▁▁▁▁▁▁', '███████████▁▁▁▁▁▁▁▁▁', '█████████████▁▁▁▁▁▁▁', '██████████████▁▁▁▁▁▁', '██████████████▁▁▁▁▁▁', '▁██████████████▁▁▁▁▁', '▁██████████████▁▁▁▁▁', '▁██████████████▁▁▁▁▁', '▁▁██████████████▁▁▁▁', '▁▁▁██████████████▁▁▁', '▁▁▁▁█████████████▁▁▁', '▁▁▁▁██████████████▁▁', '▁▁▁▁██████████████▁▁', '▁▁▁▁▁██████████████▁', '▁▁▁▁▁██████████████▁', '▁▁▁▁▁██████████████▁', '▁▁▁▁▁▁██████████████', '▁▁▁▁▁▁██████████████', '▁▁▁▁▁▁▁█████████████', '▁▁▁▁▁▁▁█████████████', '▁▁▁▁▁▁▁▁████████████', '▁▁▁▁▁▁▁▁████████████', '▁▁▁▁▁▁▁▁▁███████████', '▁▁▁▁▁▁▁▁▁███████████', '▁▁▁▁▁▁▁▁▁▁██████████', '▁▁▁▁▁▁▁▁▁▁██████████', '▁▁▁▁▁▁▁▁▁▁▁▁████████', '▁▁▁▁▁▁▁▁▁▁▁▁▁███████', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁██████', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█████', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█████', '█▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁████', '██▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁███', '██▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁███', '███▁▁▁▁▁▁▁▁▁▁▁▁▁▁███', '████▁▁▁▁▁▁▁▁▁▁▁▁▁▁██', '█████▁▁▁▁▁▁▁▁▁▁▁▁▁▁█', '█████▁▁▁▁▁▁▁▁▁▁▁▁▁▁█', '██████▁▁▁▁▁▁▁▁▁▁▁▁▁█', '████████▁▁▁▁▁▁▁▁▁▁▁▁', '█████████▁▁▁▁▁▁▁▁▁▁▁', '█████████▁▁▁▁▁▁▁▁▁▁▁', '█████████▁▁▁▁▁▁▁▁▁▁▁', '█████████▁▁▁▁▁▁▁▁▁▁▁', '███████████▁▁▁▁▁▁▁▁▁', '████████████▁▁▁▁▁▁▁▁', '████████████▁▁▁▁▁▁▁▁', '██████████████▁▁▁▁▁▁', '██████████████▁▁▁▁▁▁', '▁██████████████▁▁▁▁▁', '▁██████████████▁▁▁▁▁', '▁▁▁█████████████▁▁▁▁', '▁▁▁▁▁████████████▁▁▁', '▁▁▁▁▁████████████▁▁▁', '▁▁▁▁▁▁███████████▁▁▁', '▁▁▁▁▁▁▁▁█████████▁▁▁', '▁▁▁▁▁▁▁▁█████████▁▁▁', '▁▁▁▁▁▁▁▁▁█████████▁▁', '▁▁▁▁▁▁▁▁▁█████████▁▁', '▁▁▁▁▁▁▁▁▁▁█████████▁', '▁▁▁▁▁▁▁▁▁▁▁████████▁', '▁▁▁▁▁▁▁▁▁▁▁████████▁', '▁▁▁▁▁▁▁▁▁▁▁▁███████▁', '▁▁▁▁▁▁▁▁▁▁▁▁███████▁', '▁▁▁▁▁▁▁▁▁▁▁▁▁███████', '▁▁▁▁▁▁▁▁▁▁▁▁▁███████', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█████', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁████', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁████', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁████', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁███', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁███', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁██', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁██', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁██', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁█', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁', '▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁')
        break
      }
      'Moon' {
        $this.Name = 'Moon';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('🌑 ', '🌒 ', '🌓 ', '🌔 ', '🌕 ', '🌖 ', '🌗 ', '🌘 ')
        break
      }
      'Runner' {
        $this.Name = 'Runner';
        $this.Interval = [TimeSpan]::FromMilliseconds(140);
        $this.IsUnicode = $true;
        $this.Frames = @('🚶 ', '🏃 ')
        break
      }
      'Pong' {
        $this.Name = 'Pong';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('▐⠂       ▌', '▐⠈       ▌', '▐ ⠂      ▌', '▐ ⠠      ▌', '▐  ⡀     ▌', '▐  ⠠     ▌', '▐   ⠂    ▌', '▐   ⠈    ▌', '▐    ⠂   ▌', '▐    ⠠   ▌', '▐     ⡀  ▌', '▐     ⠠  ▌', '▐      ⠂ ▌', '▐      ⠈ ▌', '▐       ⠂▌', '▐       ⠠▌', '▐       ⡀▌', '▐      ⠠ ▌', '▐      ⠂ ▌', '▐     ⠈  ▌', '▐     ⠂  ▌', '▐    ⠠   ▌', '▐    ⡀   ▌', '▐   ⠠    ▌', '▐   ⠂    ▌', '▐  ⠈     ▌', '▐  ⠂     ▌', '▐ ⠠      ▌', '▐ ⡀      ▌', '▐⠠       ▌')
        break
      }
      'Shark' {
        $this.Name = 'Shark';
        $this.Interval = [TimeSpan]::FromMilliseconds(120);
        $this.IsUnicode = $true;
        $this.Frames = @('▐|\\____________▌', '▐_|\\___________▌', '▐__|\\__________▌', '▐___|\\_________▌', '▐____|\\________▌', '▐_____|\\_______▌', '▐______|\\______▌', '▐_______|\\_____▌', '▐________|\\____▌', '▐_________|\\___▌', '▐__________|\\__▌', '▐___________|\\_▌', '▐____________|\\▌', '▐____________/|▌', '▐___________/|_▌', '▐__________/|__▌', '▐_________/|___▌', '▐________/|____▌', '▐_______/|_____▌', '▐______/|______▌', '▐_____/|_______▌', '▐____/|________▌', '▐___/|_________▌', '▐__/|__________▌', '▐_/|___________▌', '▐/|____________▌')
        break
      }
      'Dqpb' {
        $this.Name = 'Dqpb';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $false;
        $this.Frames = @('d', 'q', 'p', 'b')
        break
      }
      'Weather' {
        $this.Name = 'Weather';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('☀️ ', '☀️ ', '☀️ ', '🌤 ', '⛅️ ', '🌥 ', '☁️ ', '🌧 ', '🌨 ', '🌧 ', '🌨 ', '🌧 ', '🌨 ', '⛈ ', '🌨 ', '🌧 ', '🌨 ', '☁️ ', '🌥 ', '⛅️ ', '🌤 ', '☀️ ', '☀️ ')
        break
      }
      'Christmas' {
        $this.Name = 'Christmas';
        $this.Interval = [TimeSpan]::FromMilliseconds(400);
        $this.IsUnicode = $true;
        $this.Frames = @('🌲', '🎄')
        break
      }
      'Grenade' {
        $this.Name = 'Grenade';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('،  ', '′  ', ' ´ ', ' ‾ ', '  ⸌', '  ⸊', '  |', '  ⁎', '  ⁕', ' ෴ ', '  ⁓', '   ', '   ', '   ')
        break
      }
      'Point' {
        $this.Name = 'Point';
        $this.Interval = [TimeSpan]::FromMilliseconds(125);
        $this.IsUnicode = $true;
        $this.Frames = @('∙∙∙', '●∙∙', '∙●∙', '∙∙●', '∙∙∙')
        break
      }
      'Layer' {
        $this.Name = 'Layer';
        $this.Interval = [TimeSpan]::FromMilliseconds(150);
        $this.IsUnicode = $true;
        $this.Frames = @('-', '=', '≡')
        break
      }
      'BetaWave' {
        $this.Name = 'BetaWave';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('ρββββββ', 'βρβββββ', 'ββρββββ', 'βββρβββ', 'ββββρββ', 'βββββρβ', 'ββββββρ')
        break
      }
      'FingerDance' {
        $this.Name = 'FingerDance';
        $this.Interval = [TimeSpan]::FromMilliseconds(160);
        $this.IsUnicode = $true;
        $this.Frames = @('🤘 ', '🤟 ', '🖖 ', '✋ ', '🤚 ', '👆 ')
        break
      }
      'FistBump' {
        $this.Name = 'FistBump';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('🤜　　　　🤛 ', '🤜　　　　🤛 ', '🤜　　　　🤛 ', '　🤜　　🤛　 ', '　　🤜🤛　　 ', '　🤜✨🤛　　 ', '🤜　✨　🤛　 ')
        break
      }
      'SoccerHeader' {
        $this.Name = 'SoccerHeader';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @(' 🧑⚽️       🧑 ', '🧑  ⚽️      🧑 ', '🧑   ⚽️     🧑 ', '🧑    ⚽️    🧑 ', '🧑     ⚽️   🧑 ', '🧑      ⚽️  🧑 ', '🧑       ⚽️🧑  ', '🧑      ⚽️  🧑 ', '🧑     ⚽️   🧑 ', '🧑    ⚽️    🧑 ', '🧑   ⚽️     🧑 ', '🧑  ⚽️      🧑 ')
        break
      }
      'Mindblown' {
        $this.Name = 'Mindblown';
        $this.Interval = [TimeSpan]::FromMilliseconds(160);
        $this.IsUnicode = $true;
        $this.Frames = @('😐 ', '😐 ', '😮 ', '😮 ', '😦 ', '😦 ', '😧 ', '😧 ', '🤯 ', '💥 ', '✨ ', '　 ', '　 ', '　 ')
        break
      }
      'Speaker' {
        $this.Name = 'Speaker';
        $this.Interval = [TimeSpan]::FromMilliseconds(160);
        $this.IsUnicode = $true;
        $this.Frames = @('🔈 ', '🔉 ', '🔊 ', '🔉 ')
        break
      }
      'OrangePulse' {
        $this.Name = 'OrangePulse';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('🔸 ', '🔶 ', '🟠 ', '🟠 ', '🔶 ')
        break
      }
      'BluePulse' {
        $this.Name = 'BluePulse';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('🔹 ', '🔷 ', '🔵 ', '🔵 ', '🔷 ')
        break
      }
      'OrangeBluePulse' {
        $this.Name = 'OrangeBluePulse';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('🔸 ', '🔶 ', '🟠 ', '🟠 ', '🔶 ', '🔹 ', '🔷 ', '🔵 ', '🔵 ', '🔷 ')
        break
      }
      'TimeTravel' {
        $this.Name = 'TimeTravel';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('🕛 ', '🕚 ', '🕙 ', '🕘 ', '🕗 ', '🕖 ', '🕕 ', '🕔 ', '🕓 ', '🕒 ', '🕑 ', '🕐 ')
        break
      }
      'Aesthetic' {
        $this.Name = 'Aesthetic';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @('▰▱▱▱▱▱▱', '▰▰▱▱▱▱▱', '▰▰▰▱▱▱▱', '▰▰▰▰▱▱▱', '▰▰▰▰▰▱▱', '▰▰▰▰▰▰▱', '▰▰▰▰▰▰▰', '▰▱▱▱▱▱▱')
        break
      }
      'DwarfFortress' {
        $this.Name = 'DwarfFortress';
        $this.Interval = [TimeSpan]::FromMilliseconds(80);
        $this.IsUnicode = $true;
        $this.Frames = @(' ██████£££  ', '☺██████£££  ', '☺██████£££  ', '☺▓█████£££  ', '☺▓█████£££  ', '☺▒█████£££  ', '☺▒█████£££  ', '☺░█████£££  ', '☺░█████£££  ', '☺ █████£££  ', ' ☺█████£££  ', ' ☺█████£££  ', ' ☺▓████£££  ', ' ☺▓████£££  ', ' ☺▒████£££  ', ' ☺▒████£££  ', ' ☺░████£££  ', ' ☺░████£££  ', ' ☺ ████£££  ', '  ☺████£££  ', '  ☺████£££  ', '  ☺▓███£££  ', '  ☺▓███£££  ', '  ☺▒███£££  ', '  ☺▒███£££  ', '  ☺░███£££  ', '  ☺░███£££  ', '  ☺ ███£££  ', '   ☺███£££  ', '   ☺███£££  ', '   ☺▓██£££  ', '   ☺▓██£££  ', '   ☺▒██£££  ', '   ☺▒██£££  ', '   ☺░██£££  ', '   ☺░██£££  ', '   ☺ ██£££  ', '    ☺██£££  ', '    ☺██£££  ', '    ☺▓█£££  ', '    ☺▓█£££  ', '    ☺▒█£££  ', '    ☺▒█£££  ', '    ☺░█£££  ', '    ☺░█£££  ', '    ☺ █£££  ', '     ☺█£££  ', '     ☺█£££  ', '     ☺▓£££  ', '     ☺▓£££  ', '     ☺▒£££  ', '     ☺▒£££  ', '     ☺░£££  ', '     ☺░£££  ', '     ☺ £££  ', '      ☺£££  ', '      ☺£££  ', '      ☺▓££  ', '      ☺▓££  ', '      ☺▒££  ', '      ☺▒££  ', '      ☺░££  ', '      ☺░££  ', '      ☺ ££  ', '       ☺££  ', '       ☺££  ', '       ☺▓£  ', '       ☺▓£  ', '       ☺▒£  ', '       ☺▒£  ', '       ☺░£  ', '       ☺░£  ', '       ☺ £  ', '        ☺£  ', '        ☺£  ', '        ☺▓  ', '        ☺▓  ', '        ☺▒  ', '        ☺▒  ', '        ☺░  ', '        ☺░  ', '        ☺   ', '        ☺  &', '        ☺ ☼&', '       ☺ ☼ &', '       ☺☼  &', '      ☺☼  & ', '      ‼   & ', '     ☺   &  ', '    ‼    &  ', '   ☺    &   ', '  ‼     &   ', ' ☺     &    ', '‼      &    ', '      &     ', '      &     ', '     &   ░  ', '     &   ▒  ', '    &    ▓  ', '    &    £  ', '   &    ░£  ', '   &    ▒£  ', '  &     ▓£  ', '  &     ££  ', ' &     ░££  ', ' &     ▒££  ', '&      ▓££  ', '&      £££  ', '      ░£££  ', '      ▒£££  ', '      ▓£££  ', '      █£££  ', '     ░█£££  ', '     ▒█£££  ', '     ▓█£££  ', '     ██£££  ', '    ░██£££  ', '    ▒██£££  ', '    ▓██£££  ', '    ███£££  ', '   ░███£££  ', '   ▒███£££  ', '   ▓███£££  ', '   ████£££  ', '  ░████£££  ', '  ▒████£££  ', '  ▓████£££  ', '  █████£££  ', ' ░█████£££  ', ' ▒█████£££  ', ' ▓█████£££  ', ' ██████£££  ', ' ██████£££  ')
        break
      }
      default {
        # if the spinner name is "Default" or just unknown then we resort to this default config
        $this.Name = 'Default';
        $this.Interval = [TimeSpan]::FromMilliseconds(100);
        $this.IsUnicode = $true;
        $this.Frames = @('⣷', '⣯', '⣟', '⡿', '⢿', '⣻', '⣽', '⣾')
      }
    }
  }

  [int] GetFrameIndex([int]$frameCount) {
    return $frameCount % $this.Frames.Length
  }
}
