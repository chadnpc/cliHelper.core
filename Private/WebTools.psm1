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
    $consoleType = [type]'AnsiConsole'
    $progressType = [type]'Progress'
    $settingsType = [type]'ProgressTaskSettings'
    $descColType = [type]'TaskDescriptionColumn'
    $progressBarColType = [type]'ProgressBarColumn'
    $pctColType = [type]'PercentageColumn'

    $console = $consoleType::Console
    $console.MarkupLine("[steelblue1][+][/] [steelblue1]$Progress_Msg[/]")
    $stream = $null
    $fileStream = $null
    $response = $null
    $Outdir = [IO.Path]::GetDirectoryName($outPath)
    if (![System.IO.Directory]::Exists($Outdir)) { [void][System.IO.Directory]::CreateDirectory($Outdir) }

    try {
      $request = [System.Net.HttpWebRequest]::Create($url)
      $request.UserAgent = "Mozilla/5.0"
      $fileStream = [System.IO.FileStream]::new($outPath, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
      $totalBytesReceived = 0
      $buffer = New-Object byte[] 8192

      if ($show_progress) {
        $progress = $progressType::new($console)
        $progress.RefreshRateMs = 80
        $progress.Columns.Clear()
        $progress.Columns.Add($descColType::new($progress))
        $progress.Columns.Add($progressBarColType::new($progress))
        $progress.Columns.Add($pctColType::new($progress))

        $capturedMsg = $Progress_Msg
        $capturedBuffer = $buffer
        $capturedFileStream = $fileStream
        $capturedSettings = $settingsType::new()
        $capturedSettings.MaxValue = 100
        $capturedSettings.IsIndeterminate = $true # Indeterminate while connecting

        $capturedTotal = [ref]$totalBytesReceived
        $capturedRequest = $request
        $capturedResponseRef = [ref]$null
        $capturedStreamRef = [ref]$null

        $progress.Start([System.Action[object]] {
            param([object]$ctx)
            $task = $ctx.AddTask("[lightyellow3]Connecting...[/]", $capturedSettings)

            $responseTask = $capturedRequest.GetResponseAsync()
            while (!$responseTask.IsCompleted) {
              $task.SetValue(0) # Heartbeat
              [System.Threading.Thread]::Sleep(50)
            }
            if ($responseTask.IsFaulted) { throw $responseTask.Exception.InnerException }
            $res = $responseTask.Result
            $capturedResponseRef.Value = $res
            $contentLength = $res.ContentLength
            $streamData = $res.GetResponseStream()
            $capturedStreamRef.Value = $streamData

            if ($contentLength -gt 0) {
              $task._state.IsIndeterminate = $false
              $task.SetDescription("[lightyellow3]$capturedMsg[/]")
            } else {
              $task.SetDescription("[lightyellow3]$capturedMsg[/]")
            }

            while ($true) {
              $bytesRead = $streamData.Read($capturedBuffer, 0, $capturedBuffer.Length)
              if ($bytesRead -le 0) { break }
              $capturedTotal.Value += $bytesRead
              $capturedFileStream.Write($capturedBuffer, 0, $bytesRead)

              if ($contentLength -gt 0) {
                $pct = [Math]::Min(100, [int][Math]::Round($capturedTotal.Value / $contentLength * 100))
                $task.SetValue($pct)
              } else {
                # indeterminate: heartbeat tick
                $task.SetValue(0)
              }
            }
            if ($contentLength -le 0) { $task._state.IsIndeterminate = $false }
            $task.Complete()
          }
        )
        $totalBytesReceived = $capturedTotal.Value
        $response = $capturedResponseRef.Value
        $stream = $capturedStreamRef.Value
      } else {
        # No progress display — drain the stream directly
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        while ($true) {
          $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
          if ($bytesRead -le 0) { break }
          $totalBytesReceived += $bytesRead
          $fileStream.Write($buffer, 0, $bytesRead)
        }
      }
    } catch {
      throw $_
    } finally {
      try { Invoke-Command -ScriptBlock { if ($stream) { $stream.Close() }; if ($fileStream) { $fileStream.Close() }; if ($response) { $response.Dispose() } } -ErrorAction SilentlyContinue } catch { $null }
    }
    return (Get-Item $outPath)
  }
  [IO.FileInfo] DownloadFileAsync([uri]$Uri, [string]$OutFile, $dlEvent, [bool]$verbose) {
    <#
    .SYNOPSIS
      Downloads a file synchronously while providing a live progress bar.
      Bypasses PowerShell event queues by chunking the download stream directly.
    #>
    $show_progress = $this.DownloadOptions.ShowProgress

    # --- Runtime type resolution ---
    $consoleType = [type]'AnsiConsole'
    $progressType = [type]'Progress'
    $settingsType = [type]'ProgressTaskSettings'
    $descColType = [type]'TaskDescriptionColumn'
    $progressBarColType = [type]'ProgressBarColumn'
    $pctColType = [type]'PercentageColumn'

    $console = $consoleType::Console
    $console.use_animation($false)

    if ($verbose) {
      $console.MarkupLine("  [steelblue1]Attempting to download '[/][white]$Uri[/][steelblue1]' ...[/]")
    }

    $stream = $null
    $fileStream = $null
    $response = $null
    $outPath = [IO.Path]::GetFullPath($OutFile)
    $Outdir = [IO.Path]::GetDirectoryName($outPath)
    if (![System.IO.Directory]::Exists($Outdir)) { [void][System.IO.Directory]::CreateDirectory($Outdir) }

    try {
      $request = [System.Net.HttpWebRequest]::Create($Uri)
      $request.UserAgent = "Mozilla/5.0"
      $buffer = New-Object byte[] 8192

      $fileStream = [System.IO.FileStream]::new($outPath, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
      $totalBytesReceived = 0

      if ($show_progress) {
        $progress = $progressType::new($console)
        $progress.RefreshRateMs = 80
        $progress.Columns.Clear()
        $progress.Columns.Add($descColType::new($progress))
        $progress.Columns.Add($progressBarColType::new($progress))
        $progress.Columns.Add($pctColType::new($progress))

        $capturedBuffer = $buffer
        $capturedFileStream = $fileStream
        $capturedSettings = $settingsType::new()
        $capturedSettings.MaxValue = 100
        $capturedSettings.IsIndeterminate = $true # Indeterminate initially while connecting

        $capturedTotal = [ref]$totalBytesReceived
        $capturedDlEvent = $dlEvent
        $capturedRequest = $request
        $capturedResponseRef = [ref]$null
        $capturedStreamRef = [ref]$null

        $progress.Start([System.Action[object]] {
            param([object]$ctx)
            $pbTask = $ctx.AddTask('[lightyellow3]Connecting...[/]', $capturedSettings)

            # Connect asynchronously to allow UI ticks
            $responseTask = $capturedRequest.GetResponseAsync()
            while (!$responseTask.IsCompleted) {
              $pbTask.SetValue(0)
              [System.Threading.Thread]::Sleep(50)
            }
            if ($responseTask.IsFaulted) { throw $responseTask.Exception.InnerException }
            $res = $responseTask.Result
            $capturedResponseRef.Value = $res
            $contentLength = $res.ContentLength
            $streamData = $res.GetResponseStream()
            $capturedStreamRef.Value = $streamData

            if ($contentLength -gt 0) {
              $pbTask._state.IsIndeterminate = $false
              $pbTask.SetDescription("[lightyellow3]Downloading[/]")
            } else {
              $pbTask.SetDescription("[lightyellow3]Downloading[/]")
            }

            while ($true) {
              $bytesRead = $streamData.Read($capturedBuffer, 0, $capturedBuffer.Length)
              if ($bytesRead -le 0) { break }
              $capturedTotal.Value += $bytesRead
              $capturedFileStream.Write($capturedBuffer, 0, $bytesRead)

              if ($contentLength -gt 0) {
                $pct = [Math]::Min(100, [int][Math]::Round($capturedTotal.Value / $contentLength * 100))
                $received = $capturedDlEvent.GetSizeProgress($capturedTotal.Value, $contentLength)
                $pbTask.SetDescription("[lightyellow3]Downloading[/] [grey]$received[/]")
                $pbTask.SetValue($pct)
              } else {
                # indeterminate: heartbeat tick
                $received = $capturedDlEvent.GetSizeProgress($capturedTotal.Value, $capturedTotal.Value)
                $pbTask.SetDescription("[lightyellow3]Downloading[/] [grey]$received[/]")
                $pbTask.SetValue(0)
              }
            }
            if ($contentLength -le 0) { $pbTask._state.IsIndeterminate = $false }
            $pbTask.Complete()
          }
        )
        $totalBytesReceived = $capturedTotal.Value
        $response = $capturedResponseRef.Value
        $stream = $capturedStreamRef.Value
        $contentLength = if ($response) { $response.ContentLength } else { 0 }
      } else {
        # No progress UI
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $contentLength = $response.ContentLength
        while ($true) {
          $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
          if ($bytesRead -le 0) { break }
          $totalBytesReceived += $bytesRead
          $fileStream.Write($buffer, 0, $bytesRead)
        }
      }

      if ($show_progress) {
        if ($contentLength -le 0 -or $totalBytesReceived -ge $contentLength) {
          $console.MarkupLine("  [green]✓ Downloaded $($dlEvent.GetSizeProgress($totalBytesReceived, $totalBytesReceived))[/]")
        } else {
          $console.MarkupLine("  [red]✗ Download failed: $($Uri.AbsoluteUri)[/]")
        }
      }
    } catch {
      $escapedMsg = $_.Exception.GetBaseException().Message -replace '\[', '[[' -replace '\]', ']]'
      $console.MarkupLine("  [red]$escapedMsg[/]")
      throw $_
    } finally {
      if ($verbose -and [IO.File]::Exists($outPath)) {
        $console.MarkupLine("  [steelblue1]OutPath: '[/][white]$outPath[/][steelblue1]'[/]")
      }
      try { Invoke-Command -ScriptBlock { if ($stream) { $stream.Close() }; if ($fileStream) { $fileStream.Close() }; if ($response) { $response.Dispose() } } -ErrorAction SilentlyContinue } catch {}
    }

    if ([IO.File]::Exists($outPath)) {
      return Get-Item $outPath
    } else {
      return [IO.FileInfo]::new($outPath)
    }
  }
}
