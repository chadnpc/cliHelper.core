using namespace System.Net

using module .\Enums.psm1
using module .\Abstracts.psm1
using module .\Console.psm1
using module .\Console\Internal.psm1
using module .\Utilities.psm1

# downloadhelper
class dlh {
  [string]$Id
  static [PsRecord] $DownloadOptions = @{
    ShowProgress      = $true
    ProgressBarLength = { return [int]([ConsoleWriter]::get_ConsoleWidth() * 0.7) }
    ProgressMessage   = [string]::Empty
    RetryTimeout      = 1000
    Headers           = @{}
    Proxy             = $null
    Force             = $false
  }
  dlh() {
    $this.Id = [Guid]::NewGuid().Guid.replace('-', '').SubString(0, 20)
    $this.PsObject.Properties.Add([PSScriptProperty]::new('Data', [scriptblock]::Create("`$e = Get-Event -SourceIdentifier $($this.Id) -ea Ignore; if (`$e) { return `$e[-1].SourceEventArgs }; return `$null")))
  }
  [string] GetfileSize([long]$Bytes) {
    $sizestr = switch ($bytes) {
      { $bytes -lt 1MB } { "$([Math]::Round($bytes / 1KB, 2)) KB"; break }
      { $bytes -lt 1GB } { "$([Math]::Round($bytes / 1MB, 2)) MB"; break }
      { $bytes -lt 1TB } { "$([Math]::Round($bytes / 1GB, 2)) GB"; break }
      default { "$([Math]::Round($bytes / 1TB, 2)) TB" }
    }
    return [string]$sizestr
  }
  [string] GetSizeProgress() {
    if ($null -eq $this.Data) {
      return [string]::Empty
    }
    return $this.GetSizeProgress($this.Data.BytesReceived, $this.Data.TotalBytesToReceive)
  }
  [string] GetSizeProgress($r, $t) {
    return "{0} / {1}" -f $($this.GetfileSize($r)), $($this.GetfileSize($t))
  }

  static [IO.FileInfo] DownloadFile([uri]$url) {
    $randomSuffix = [Guid]::NewGuid().Guid.subString(15).replace('-', [string]::Join('', (0..9 | Get-Random -Count 1)))
    return [dlh]::DownloadFile($url, "$(Split-Path $url.AbsolutePath -Leaf)_$randomSuffix")
  }

  static [IO.FileInfo] DownloadFile([uri]$url, [string]$outFile) {
    return [dlh]::DownloadFile($url, $outFile, $false)
  }

  static [IO.FileInfo] DownloadFile([uri]$url, [string]$outFile, [bool]$Force) {
    [ValidateNotNullOrEmpty()][uri]$url = $url
    [ValidateNotNullOrEmpty()][string]$outFile = $outFile
    $stream = $null; $fileStream = $null
    $name = Split-Path $url -Leaf
    $request = [System.Net.HttpWebRequest]::Create($url)
    $request.UserAgent = "Mozilla/5.0"
    $response = $request.GetResponse()
    $contentLength = $response.ContentLength
    $stream = $response.GetResponseStream()
    $buffer = New-Object byte[] 1024
    $outPath = [IO.Path]::GetFullPath($outFile)
    if ([System.IO.Directory]::Exists($outFile)) {
      if (!$Force) { throw [ArgumentException]::new("Please provide valid file path, not a directory.", "outFile") }
      $outPath = Join-Path -Path $outFile -ChildPath $name
    }
    $Outdir = [IO.Path]::GetDirectoryName($outPath)
    if (![System.IO.Directory]::Exists($Outdir)) { [void][System.IO.Directory]::CreateDirectory($Outdir) }
    if ([IO.File]::Exists($outPath)) {
      if (!$Force) { throw "$outFile already exists" }
      Remove-Item $outPath -Force -ErrorAction Ignore | Out-Null
    }
    $fileStream = [System.IO.FileStream]::new($outPath, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $totalBytesReceived = 0
    $totalBytesToReceive = $contentLength
    $OgForeground = (Get-Variable host).Value.UI.RawUI.ForegroundColor
    $Progress_Msg = [dlh]::DownloadOptions.ProgressMessage
    if ([string]::IsNullOrWhiteSpace($Progress_Msg)) { $Progress_Msg = "[+] Downloading $name to $outFile" }
    Write-Host $Progress_Msg -ForegroundColor Magenta
    $(Get-Variable host).Value.UI.RawUI.ForegroundColor = [ConsoleColor]::Green
    while ($totalBytesToReceive -gt 0) {
      $bytesRead = $stream.Read($buffer, 0, 1024)
      $totalBytesReceived += $bytesRead
      $totalBytesToReceive -= $bytesRead
      $fileStream.Write($buffer, 0, $bytesRead)
      if ([dlh]::DownloadOptions.ShowProgress) {
        [int]$PMetric = [math]::Round($totalBytesReceived / $contentLength * 100)
        [ProgressUtil]::WriteProgressBar($PMetric, $true, [dlh]::DownloadOptions.progressBarLength)
      }
    }
    $(Get-Variable host).Value.UI.RawUI.ForegroundColor = $OgForeground
    try { Invoke-Command -ScriptBlock { $stream.Close(); $fileStream.Close() } -ErrorAction SilentlyContinue } catch { $null }
    return (Get-Item $outFile)
  }
  static [IO.FileInfo] DownloadFileAsync([uri]$Uri, [string]$OutFile, $dlEvent, [bool]$verbose) {
    try {
      $webClient = [System.Net.WebClient]::new()
      # $webClient.Credentials = $login
      $task = $webClient.DownloadFileTaskAsync($Uri, $OutFile)
      Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -SourceIdentifier $dlEvent.Id | Out-Null
      $verbose ? (Write-Console "  Attempting to download '$Uri' ..." -f SteelBlue) : $null
      while (!$task.IsCompleted) {
        if ($null -ne $dlEvent.Data) {
          $ReceivedData = $dlEvent.Data.BytesReceived
          $TotalToReceive = $dlEvent.Data.TotalBytesToReceive
          $TotalPercent = $dlEvent.Data.ProgressPercentage
          if ($null -ne $ReceivedData) {
            [ProgressUtil]::WriteProgressBar([int]$TotalPercent, "  Downloading : $($dlEvent.GetSizeProgress($ReceivedData, $TotalToReceive))")
          }
        }
        [System.Threading.Thread]::Sleep(50)
      }
    } catch {
      Write-Console $_.Exception.Message -f Salmon
      throw $_
    } finally {
      $verbose ? ([ProgressUtil]::WriteProgressBar(100, $true, "  Downloaded $($dlEvent.GetSizeProgress())", $true)) : $null
      if ([IO.File]::Exists($OutFile)) {
        $verbose ? (Write-Console "  OutPath: '$OutFile'" -f SteelBlue) : $null
      }
      Invoke-Command { $webClient.Dispose(); Unregister-Event -SourceIdentifier $dlEvent.Id -Force -ea Ignore } -ea Ignore
    }
    if ([IO.File]::Exists($OutFile)) {
      return Get-Item $OutFile
    } else {
      return [IO.FileInfo]::new($OutFile)
    }
  }
}
