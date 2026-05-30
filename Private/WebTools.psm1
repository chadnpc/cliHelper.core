using namespace System.Net

using module .\Enums.psm1
using module .\Abstracts.psm1
using module .\Console.psm1
using module .\Console\Internal.psm1
using module .\Utilities.psm1

# downloadhelper
class DownloadHelper {
  [string]$Id
  hidden [pscustomobject] $DownloadOptions
  DownloadHelper() {
    $this.Id = [Guid]::NewGuid().Guid.replace('-', '').SubString(0, 20)
    $this.PsObject.Properties.Add([PSScriptProperty]::new('Data', [scriptblock]::Create("`$e = Get-Event -SourceIdentifier $($this.Id) -ea Ignore; if (`$e) { return `$e[-1].SourceEventArgs }; return `$null")))
    $Options = [pscustomobject]@{
      ProgressMessage = [string]::Empty
      RetryTimeout    = 1000
      Headers         = @{}
      Proxy           = $null
      Force           = $false
    }
    $Options.PsObject.Properties.Add([PSScriptProperty]::new('ProgressBarLength', [scriptblock]::Create("return [int]([ConsoleWriter]::get_ConsoleWidth() * 0.7)")))
    $Options.PsObject.Properties.Add([PSScriptProperty]::new('ShowProgress', [scriptblock]::Create("return (`$global:ProgressPreference -eq 'Continue')")))
    $this.DownloadOptions = $Options
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

  [IO.FileInfo] DownloadFile([uri]$url) {
    $randomSuffix = [Guid]::NewGuid().Guid.subString(15).replace('-', [string]::Join('', (0..9 | Get-Random -Count 1)))
    return $this.DownloadFile($url, "$(Split-Path $url.AbsolutePath -Leaf)_$randomSuffix")
  }

  [IO.FileInfo] DownloadFile([uri]$url, [string]$outFile) {
    return $this.DownloadFile($url, $outFile, $false)
  }

  [IO.FileInfo] DownloadFile([uri]$url, [string]$outFile, [bool]$Force) {
    [ValidateNotNullOrEmpty()][uri]$url = $url
    [ValidateNotNullOrEmpty()][string]$outFile = $outFile
    $stream = $null; $fileStream = $null
    $name = Split-Path $url -Leaf
    $request = [System.Net.HttpWebRequest]::Create($url)
    $request.UserAgent = "Mozilla/5.0"
    $response = $request.GetResponse()
    $contentLength = $response.ContentLength
    $stream = $response.GetResponseStream()
    $buffer = New-Object byte[] 8192
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
    $Progress_Msg = $this.DownloadOptions.ProgressMessage
    $show_progress = $this.DownloadOptions.ShowProgress
    if ([string]::IsNullOrWhiteSpace($Progress_Msg)) { $Progress_Msg = "Downloading $name" }

    # --- Runtime type resolution (avoids parse-time forward-ref failures) ---
    $consoleType        = [type]'AnsiConsole'
    $progressType       = [type]'Progress'
    $settingsType       = [type]'ProgressTaskSettings'
    $descColType        = [type]'TaskDescriptionColumn'
    $progressBarColType = [type]'ProgressBarColumn'
    $pctColType         = [type]'PercentageColumn'

    $console  = $consoleType::Console
    $console.MarkupLine("[steelblue1][+][/] [steelblue1]$Progress_Msg[/]")

    if ($show_progress) {
      $progress = $progressType::new($console)
      $progress.RefreshRateMs = 80
      $progress.Columns.Clear()
      $progress.Columns.Add($descColType::new($progress))
      $progress.Columns.Add($progressBarColType::new($progress))
      $progress.Columns.Add($pctColType::new($progress))

      $capturedMsg      = $Progress_Msg
      $capturedStream   = $stream
      $capturedBuffer   = $buffer
      $capturedFileStream = $fileStream
      $capturedLength   = $contentLength
      $capturedSettings = $settingsType::new()
      $capturedSettings.MaxValue = 100
      $capturedSettings.IsIndeterminate = $contentLength -le 0

      $capturedTotal = [ref]$totalBytesReceived

      $progress.Start([System.Action[object]] {
          param([object]$ctx)
          $task = $ctx.AddTask("[lightyellow3]$capturedMsg[/]", $capturedSettings)
          while ($true) {
            $bytesRead = $capturedStream.Read($capturedBuffer, 0, $capturedBuffer.Length)
            if ($bytesRead -le 0) { break }
            $capturedTotal.Value += $bytesRead
            $capturedFileStream.Write($capturedBuffer, 0, $bytesRead)
            if ($capturedLength -gt 0) {
              $pct = [Math]::Min(100, [int][Math]::Round($capturedTotal.Value / $capturedLength * 100))
              $task.SetValue($pct)
            } else {
              # indeterminate: heartbeat tick to animate the bar
              $task.SetValue(0)
            }
          }
          $task.Complete()
        }
      )
      $totalBytesReceived = $capturedTotal.Value
    } else {
      # No progress display — drain the stream directly
      while ($true) {
        $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
        if ($bytesRead -le 0) { break }
        $totalBytesReceived += $bytesRead
        $fileStream.Write($buffer, 0, $bytesRead)
      }
    }

    try { Invoke-Command -ScriptBlock { $stream.Close(); $fileStream.Close() } -ErrorAction SilentlyContinue } catch { $null }
    return (Get-Item $outPath)
  }
  [IO.FileInfo] DownloadFileAsync([uri]$Uri, [string]$OutFile, $dlEvent, [bool]$verbose) {
    <#
    .SYNOPSIS
      Async download using WebClient.DownloadFileTaskAsync driven by a Spectre.Console
      Progress live bar. Register-ObjectEvent captures DownloadProgressChanged events;
      the Progress.Start() action polls those events and calls task.SetValue() each tick.
    #>
    $show_progress = $this.DownloadOptions.ShowProgress

    # --- Runtime type resolution ---
    $consoleType        = [type]'AnsiConsole'
    $progressType       = [type]'Progress'
    $settingsType       = [type]'ProgressTaskSettings'
    $descColType        = [type]'TaskDescriptionColumn'
    $progressBarColType = [type]'ProgressBarColumn'
    $pctColType         = [type]'PercentageColumn'

    $console = $consoleType::Console

    if ($verbose) {
      $console.MarkupLine("  [steelblue1]Attempting to download '[/][white]$Uri[/][steelblue1]' ...[/]")
    }

    $webClient = $null
    try {
      $webClient = [System.Net.WebClient]::new()
      $task      = $webClient.DownloadFileTaskAsync($Uri, $OutFile)

      # Register the progress-changed event so $dlEvent.Data is populated
      Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -SourceIdentifier $dlEvent.Id | Out-Null

      if ($show_progress) {
        $progress = $progressType::new($console)
        $progress.RefreshRateMs = 80
        $progress.Columns.Clear()
        $progress.Columns.Add($descColType::new($progress))
        $progress.Columns.Add($progressBarColType::new($progress))
        $progress.Columns.Add($pctColType::new($progress))

        $capturedTask    = $task
        $capturedDlEvent = $dlEvent
        $capturedSettings = $settingsType::new()
        $capturedSettings.MaxValue = 100
        $capturedSettings.IsIndeterminate = $false

        $progress.Start([System.Action[object]] {
            param([object]$ctx)
            $pbTask = $ctx.AddTask('[lightyellow3]Downloading[/]', $capturedSettings)
            while (!$capturedTask.IsCompleted) {
              $evtData = $capturedDlEvent.Data
              if ($null -ne $evtData) {
                $pct = [Math]::Max(0, [Math]::Min(100, [int]$evtData.ProgressPercentage))
                $received = $capturedDlEvent.GetSizeProgress($evtData.BytesReceived, $evtData.TotalBytesToReceive)
                $pbTask.SetDescription("[lightyellow3]Downloading[/] [grey]$received[/]")
                $pbTask.SetValue($pct)
              } else {
                # Event data not yet available — indeterminate heartbeat
                $pbTask.SetValue(0)
              }
              [System.Threading.Thread]::Sleep(50)
            }
            $pbTask.Complete()
          }
        )
      } else {
        # No progress UI — just wait for completion
        while (!$task.IsCompleted) {
          [System.Threading.Thread]::Sleep(50)
        }
      }

      if ($task.IsFaulted) {
        throw $task.Exception.GetBaseException()
      }
    } catch {
      $console.MarkupLine("  [red]$($_.Exception.Message)[/]")
      throw $_
    } finally {
      if ($show_progress -and $null -ne $dlEvent.Data) {
        if ($dlEvent.Data.BytesReceived -eq $dlEvent.Data.TotalBytesToReceive -and $dlEvent.Data.TotalBytesToReceive -gt 0) {
          $console.MarkupLine("  [green]✓ Downloaded $($dlEvent.GetSizeProgress())[/]")
        } else {
          $console.MarkupLine("  [red]✗ Download failed: $($Uri.AbsoluteUri)[/]")
        }
      }
      if ($verbose -and [IO.File]::Exists($OutFile)) {
        $console.MarkupLine("  [steelblue1]OutPath: '[/][white]$OutFile[/][steelblue1]'[/]")
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
