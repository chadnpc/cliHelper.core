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
    $name = Split-Path $url -Leaf
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

    $Progress_Msg = $this.DownloadOptions.ProgressMessage
    $show_progress = $this.DownloadOptions.ShowProgress
    if ([string]::IsNullOrWhiteSpace($Progress_Msg)) { $Progress_Msg = "Downloading $name" }

    # --- Runtime type resolution (avoids parse-time forward-ref failures) ---
    $consoleType = [type]'AnsiConsole'
    $progressType = [type]'Progress'
    $statusType = [type]'Status'
    $settingsType = [type]'ProgressTaskSettings'
    $descColType = [type]'TaskDescriptionColumn'
    $progressBarColType = [type]'ProgressBarColumn'
    $pctColType = [type]'PercentageColumn'
    $spinnerColType = [type]'SpinnerColumn'

    $console = $consoleType::Console
    $console.MarkupLine("[steelblue1][+][/] [steelblue1]$Progress_Msg[/]")

    $stream = $null
    $fileStream = $null
    $response = $null
    $totalBytesReceived = 0
    $buffer = New-Object byte[] 8192
    $fileStream = [System.IO.FileStream]::new($outPath, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)

    try {
      $request = [System.Net.HttpWebRequest]::Create($url)
      $request.UserAgent = "Mozilla/5.0"
      $capturedRequest = $request
      $capturedResponseRef = [ref]$null

      if ($show_progress) {
        # ── Phase 1: Spinner while waiting for the HTTP response ──────────────
        $status = $statusType::new($console.GetWriter())
        $status.Spinner = ""
        $status.RefreshRateMs = 80

        $status.Start('Connecting…', {
            param($sctx)
            $responseTask = $capturedRequest.GetResponseAsync()
            while (!$responseTask.IsCompleted) {
              [System.Threading.Thread]::Sleep(50)
            }
            if ($responseTask.IsFaulted) { throw $responseTask.Exception.InnerException }
            $capturedResponseRef.Value = $responseTask.Result
            $sctx.Complete()
          }
        )

        $response = $capturedResponseRef.Value
        $contentLength = $response.ContentLength
        $stream = $response.GetResponseStream()

        # ── Phase 2: Deterministic progress bar for the download body ─────────
        $capturedBuffer = $buffer
        $capturedFileStream = $fileStream
        $capturedSettings = $settingsType::new()
        $capturedSettings.MaxValue = 100
        $capturedSettings.IsIndeterminate = ($contentLength -le 0)

        $capturedTotal = [ref]$totalBytesReceived
        $capturedStream = $stream
        $capturedLen = $contentLength
        $capturedMsg = $Progress_Msg

        $progress = $progressType::new($console)
        $progress.RefreshRateMs = 80
        $progress.Columns.Clear()
        $progress.Columns.Add($descColType::new($progress))
        $progress.Columns.Add($progressBarColType::new($progress))
        $progress.Columns.Add($pctColType::new($progress))
        $progress.Columns.Add($spinnerColType::new($progress))

        $progress.Start([System.Action[object]] {
            param([object]$ctx)
            $task = $ctx.AddTask("[lightyellow3]$capturedMsg[/]", $capturedSettings)

            while ($true) {
              $bytesRead = $capturedStream.Read($capturedBuffer, 0, $capturedBuffer.Length)
              if ($bytesRead -le 0) { break }
              $capturedTotal.Value += $bytesRead
              $capturedFileStream.Write($capturedBuffer, 0, $bytesRead)

              if ($capturedLen -gt 0) {
                $pct = [Math]::Min(100, [int][Math]::Round($capturedTotal.Value / $capturedLen * 100))
                $task.SetValue($pct)
              } else {
                $task.SetValue(0) # indeterminate: just tick
              }
            }
            if ($capturedLen -le 0) { $task._state.IsIndeterminate = $false }
            $task.Complete()
          }
        )
        $totalBytesReceived = $capturedTotal.Value
      } else {
        # No progress display — drain the stream directly
        $response = $request.GetResponse()
        $contentLength = $response.ContentLength
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
      try { if ($stream) { $stream.Close() } } catch { $null }
      try { if ($fileStream) { $fileStream.Close() } } catch { $null }
      try { if ($response) { $response.Dispose() } } catch { $null }
    }
    return (Get-Item $outPath)
  }
  [IO.FileInfo] DownloadFileAsync([uri]$Uri, [string]$OutFile, $dlEvent, [bool]$verbose) {
    <#
    .SYNOPSIS
      Downloads a file synchronously while providing a live progress bar.
      Phase 1 — spinner while waiting for HTTP response headers.
      Phase 2 — deterministic progress bar while streaming the body.
    #>
    $show_progress = $this.DownloadOptions.ShowProgress

    # --- Runtime type resolution (avoids parse-time forward-ref failures) ---
    $consoleType = [type]'AnsiConsole'
    $progressType = [type]'Progress'
    $statusType = [type]'Status'
    $settingsType = [type]'ProgressTaskSettings'
    $descColType = [type]'TaskDescriptionColumn'
    $progressBarColType = [type]'ProgressBarColumn'
    $pctColType = [type]'PercentageColumn'
    $spinnerColType = [type]'SpinnerColumn'


    $console = $consoleType::Console
    $console.use_animation($false)

    if ($verbose) {
      $console.MarkupLine("  [steelblue1]Attempting to download '[/][white]$Uri[/][steelblue1]' ...[/]")
    }

    $stream = $null
    $fileStream = $null
    $response = $null
    $contentLength = 0
    $totalBytesReceived = 0
    $outPath = [IO.Path]::GetFullPath($OutFile)
    $Outdir = [IO.Path]::GetDirectoryName($outPath)
    if (![System.IO.Directory]::Exists($Outdir)) { [void][System.IO.Directory]::CreateDirectory($Outdir) }

    try {
      $request = [System.Net.HttpWebRequest]::Create($Uri)
      $request.UserAgent = "Mozilla/5.0"
      $buffer = New-Object byte[] 8192
      $fileStream = [System.IO.FileStream]::new($outPath, [IO.FileMode]::Create, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
      $capturedRequest = $request
      $capturedResponseRef = [ref]$null

      if ($show_progress) {
        # ── Phase 1: Spinner while waiting for the HTTP response ──────────────
        $status = $statusType::new($console.GetWriter())
        $status.Spinner = ""
        $status.RefreshRateMs = 80

        $status.Start('Connecting…', {
            param($sctx)
            $responseTask = $capturedRequest.GetResponseAsync()
            while (!$responseTask.IsCompleted) {
              [System.Threading.Thread]::Sleep(50)
            }
            if ($responseTask.IsFaulted) { throw $responseTask.Exception.InnerException }
            $capturedResponseRef.Value = $responseTask.Result
            $sctx.Complete()
          }
        )

        $response = $capturedResponseRef.Value
        $contentLength = $response.ContentLength
        $stream = $response.GetResponseStream()

        # ── Phase 2: Deterministic progress bar for the download body ─────────
        $capturedBuffer = $buffer
        $capturedFileStream = $fileStream
        $capturedDlEvent = $dlEvent
        $capturedSettings = $settingsType::new()
        $capturedSettings.MaxValue = 100
        $capturedSettings.IsIndeterminate = ($contentLength -le 0)

        $capturedTotal = [ref]$totalBytesReceived
        $capturedStream = $stream
        $capturedLen = $contentLength

        $progress = $progressType::new($console)
        $progress.RefreshRateMs = 80
        $progress.Columns.Clear()
        $progress.Columns.Add($descColType::new($progress))
        $progress.Columns.Add($progressBarColType::new($progress))
        $progress.Columns.Add($pctColType::new($progress))
        $progress.Columns.Add($spinnerColType::new($progress))

        $progress.Start([System.Action[object]] {
            param([object]$ctx)
            $pbTask = $ctx.AddTask('[lightyellow3]Downloading[/]', $capturedSettings)

            while ($true) {
              $bytesRead = $capturedStream.Read($capturedBuffer, 0, $capturedBuffer.Length)
              if ($bytesRead -le 0) { break }
              $capturedTotal.Value += $bytesRead
              $capturedFileStream.Write($capturedBuffer, 0, $bytesRead)

              if ($capturedLen -gt 0) {
                $pct = [Math]::Min(100, [int][Math]::Round($capturedTotal.Value / $capturedLen * 100))
                $received = $capturedDlEvent.GetSizeProgress($capturedTotal.Value, $capturedLen)
                $pbTask.SetDescription("[lightyellow3]Downloading[/] [grey]$received[/]")
                $pbTask.SetValue($pct)
              } else {
                $received = $capturedDlEvent.GetSizeProgress($capturedTotal.Value, $capturedTotal.Value)
                $pbTask.SetDescription("[lightyellow3]Downloading[/] [grey]$received[/]")
                $pbTask.SetValue(0)
              }
            }
            if ($capturedLen -le 0) { $pbTask._state.IsIndeterminate = $false }
            $pbTask.Complete()
          }
        )
        $totalBytesReceived = $capturedTotal.Value
      } else {
        # No progress UI
        $response = $request.GetResponse()
        $contentLength = $response.ContentLength
        $stream = $response.GetResponseStream()
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
      try { if ($stream) { $stream.Close() } } catch { $null }
      try { if ($fileStream) { $fileStream.Close() } } catch { $null }
      try { if ($response) { $response.Dispose() } } catch { $null }
    }

    if ([IO.File]::Exists($outPath)) {
      return Get-Item $outPath
    } else {
      return [IO.FileInfo]::new($outPath)
    }
  }
}
