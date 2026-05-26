using namespace System.Collections.Generic

using module .\Enums.psm1
using module .\Console\Colors.psm1

#region    console_art
# .SYNOPSIS
#  cliart helper.
# .DESCRIPTION
#  A class to convert dot ascii arts to b64string & vice versa
# .LINK
#  https://getcliart.vercel.app
# .EXAMPLE
#  $art = [cliart]::Create("https://pastebin.com/raw/p29UR385")
#  same as
#  $art = [cliart]"https://pastebin.com/raw/p29UR385"
# .EXAMPLE
#  $a = [cliart]"/en-US/ascii.txt"
#  [void]$a.replace('x', 0).Replace('y', 1).Replace('z', 3)
#  $a.GetString() | Write-Host -f Green
#  $print_expression = $a.GetPrinter()
#  Now instead of hard coding the content of the art file, you can use $print_expression anywhere in your script
class cliart {
  hidden [list[string]] $taglines = @()
  hidden [ValidateNotNullOrWhiteSpace()][string] $CompressedStr
  cliart() { }
  cliart([byte[]]$bytes) { [void][cliart]::_init_($bytes, [ref]$this) }
  cliart([string]$string) { [void][cliart]::_init_($string, [string[]]@(), [ref]$this) }
  cliart([IO.FileInfo]$file) { [void][cliart]::_init_($file, [ref]$this) }

  static [cliart] Create([byte[]]$bytes) { return [cliart]::_init_($bytes, [ref][cliart]::new()) }
  static [cliart] Create([string]$string) { return [cliart]::_init_($string, [ref][cliart]::new()) }
  static [cliart] Create([IO.FileInfo]$file) { return [cliart]::_init_($file, [ref][cliart]::new()) }
  static [cliart] Create([byte[]]$bytes, [string[]]$taglines) { return [cliart]::_init_($bytes, $taglines, [ref][cliart]::new()) }
  static [cliart] Create([string]$string, [string[]]$taglines) { return [cliart]::_init_($string, $taglines, [ref][cliart]::new()) }

  static hidden [cliart] _init_([string]$s, $o) {
    # $o.Value.CompressedStr = $s; return $o.Value
    return [cliart]::_init_($s, @(), $o)
  }
  static hidden [cliart] _init_([string]$s, [string[]]$taglines, $o) {
    $from_url = $false; $use_verbose = (Get-Variable VerbosePreference -Scope global -ValueOnly) -eq 'Continue'
    $i = switch ($true) {
      ([cryptobase]::IsValidUrl($s)) { $from_url = $true; $dlfile = $(Start-DownloadWithRetry -Uri $s -Message "downloading" -Verbose:$use_verbose -caller '[cliart]'); Get-Item $dlfile; break }
      ([cryptobase]::IsBase64String($s)) { [System.Convert]::FromBase64String($s); break }
      ([cliart]::ResolveRelativeFilePath([ref]$s)) { (Get-Item $s); break }
      default {
        throw [ArgumentException]::new('Invalid input string. [cliart]::Create() requires a valid url, base64 string or valid file path.')
      }
    }
    $o.Value.CompressedStr = [cliart]::_init_($i, $o).CompressedStr;
    if ([IO.File]::Exists($i) -and $from_url) { Remove-Item $i -Verbose:$false -Force -ea Ignore }
    if ($taglines.Count -gt 0) { $taglines.ForEach({ [void]$o.Value.taglines.Add($_) }) }
    return $o.Value
  }
  static hidden [cliart] _init_([IO.FileInfo]$file, $o) {
    return [cliart]::_init_([IO.File]::ReadAllBytes($file.FullName), @(), $o)
  }
  static hidden [cliart] _init_([byte[]]$bytes, [string[]]$taglines, $o) {
    $o.Value.CompressedStr = [cliart]::ToCompressedB64([convert]::ToBase64String($bytes))
    if ($taglines.Count -gt 0) { $taglines.ForEach({ [void]$o.Value.taglines.Add($_) }) }
    return $o.Value
  }
  static [string] Print([string]$CompressedStr) {
    if ([string]::IsNullOrWhiteSpace($CompressedStr)) { return [string]::Empty }
    return [cliart]::FromCompressedB64($CompressedStr)
  }
  hidden [string] GetPrinter() {
    return '[cliart]::Print("{0}")' -f $this.CompressedStr
  }
  [void] Write() {
    $this.Write($true)
  }
  [void] Write([bool]$Animate) {
    $this.Write(0, $true, $Animate)
  }
  [void] Write([string]$AdditionalText) {
    $this.Write('LimeGreen', 0, $true, $AdditionalText, $true)
  }
  [void] Write([int]$SpaceBeforeTagline, [bool]$Nonewline, [bool]$Animate) {
    $this.Write('LimeGreen', $SpaceBeforeTagline, $Nonewline, [string]::Empty, $Animate)
  }
  [void] Write([string]$ArtRGBcolor, [int]$SpaceBeforeTagline, [bool]$Nonewline, [string]$AdditionalText, [bool]$Animate) {
    $this.Write($ArtRGBcolor, $SpaceBeforeTagline, $ArtRGBcolor, $Nonewline, $AdditionalText, $Animate)
  }
  [void] Write([string]$ArtRGBcolor, [int]$SpaceBeforeTagline, [string]$TaglineRGBbcolor, [bool]$Nonewline, [string]$AdditionalText, [bool]$Animate) {
    [ValidateScript( { return [bool][RGB]$_ })][string]$ArtRGBcolor = $ArtRGBcolor
    [ValidateScript( { return [bool][RGB]$_ })][string]$TaglineRGBbcolor = $TaglineRGBbcolor
    $this.GetString() | Write-Console -f $ArtRGBcolor; $last_line = '{0}{1}' -f $([string][char]32 * $SpaceBeforeTagline), $this.GetTagline()
    if (![string]::IsNullOrWhiteSpace($last_line)) { $last_line | Write-Console -f $TaglineRGBbcolor -NoNewLine:$Nonewline -Animate:$Animate }
    if (![string]::IsNullOrWhiteSpace($AdditionalText)) { $AdditionalText | Write-Console -f LightCyan -Animate:$Animate }
  }
  [cliart] Replace([string]$oldValue, [string]$newValue) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($this.GetString().replace($oldValue, $newValue))
    $this.CompressedStr = [cliart]::ToCompressedB64([convert]::ToBase64String($bytes))
    return $this
  }
  [string] GetString() {
    return [cliart]::Print($this.CompressedStr)
  }
  [string] GetTagline() { return $this.taglines | Get-Random }

  static hidden [bool] ResolveRelativeFilePath($pathref) {
    $path = $pathref.Value
    if ([IO.Path]::IsPathFullyQualified($path)) {
      return $true
    }
    $unresPath = Join-Path (Get-Location).Path $path -ea Ignore
    $pathref.Value = [IO.Path]::Exists($unresPath) ? $unresPath : [string]::Empty
    return ![string]::IsNullOrEmpty($pathref.Value)
  }
  static [string] ToCompressedB64([string]$Base64String) {
    if (!([cryptobase]::IsBase64String($Base64String))) {
      throw [System.ArgumentException]::new('Invalid base64 string. ToCompressedB64() requires a valid base64 string.')
    }
    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($Base64String)
    $outstream = [System.IO.MemoryStream]::new()
    $Comstream = [System.IO.Compression.GzipStream]::new($outstream, [System.IO.Compression.CompressionLevel]::Optimal)
    [void]$Comstream.Write($Bytes, 0, $Bytes.Length); $Comstream.Close(); $Comstream.Dispose();
    [byte[]]$OutPut = $outstream.ToArray(); $outStream.Close()
    return [convert]::ToBase64String($OutPut)
  }
  static [string] FromCompressedB64([string]$Base64String) {
    if (!([cryptobase]::IsBase64String($Base64String))) {
      throw [System.ArgumentException]::new('Invalid base64 string. FromCompressedB64() requires a valid base64 string.')
    }
    $inpStream = [System.IO.MemoryStream]::new([Convert]::FromBase64String($Base64String))
    $ComStream = [System.IO.Compression.GzipStream]::new($inpStream, [System.IO.Compression.CompressionMode]::Decompress)
    $outStream = [System.IO.MemoryStream]::new();
    [void]$Comstream.CopyTo($outStream); $Comstream.Close(); $Comstream.Dispose(); $inpStream.Close()
    [byte[]]$OutPut = $outStream.ToArray(); $outStream.Close()
    return [System.Text.Encoding]::UTF8.GetString([convert]::FromBase64String([System.Text.Encoding]::UTF8.GetString($OutPut)))
  }
  [string] ToString() {
    return $this.GetString()
  }
}

#endregion console_art

class MotdGen {
  static [void] ClearMotd() {
    if (Test-Path "$env:USERPROFILE\.motd") {
      Remove-Item "$env:USERPROFILE\.motd" -Force
    }
  }
  static [cliart] GenerateMotd([string]$Art, [string[]]$Taglines) {
    return [cliart]::Create($Art, $Taglines)
  }
  static [void] ShowMotd([cliart]$Motd) {
    if ($null -ne $Motd) {
      $Motd.Write()
    }
  }
}
