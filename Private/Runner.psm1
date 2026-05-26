using namespace System
using namespace System.Threading
using namespace System.Collections
using namespace System.Threading.Workers
using namespace System.Collections.Generic
using namespace System.Management.Automation
using namespace System.Collections.Concurrent
using namespace System.Management.Automation.Runspaces


using module .\ErrorMan.psm1
using module .\Config.psm1
using module .\Models.psm1
using module .\Console.psm1
using module .\Console\Internal.psm1
using module .\Utilities.psm1


class JobResult {
  [string]$Name
  [bool]$Success
  [PSDataCollection[psobject]]$Output
  hidden [int]$Index # from BackgroundJob 's index
  hidden [object]$Error
  hidden [string]$Status
  hidden [int]$DurationMs
  hidden [System.Diagnostics.Stopwatch]$Stopwatch
}

class BackgroundJob {
  [string]$Name
  [object[]]$Arguments
  [double]$Progress = 0
  [string]$Status = "Pending"
  [string]$StatusMessage = ""
  [System.Diagnostics.Stopwatch]$Stopwatch = @{}
  [string]$ElapsedTime = "00:00.0"
  # Use Runspace instance
  hidden [PowerShell]$PowerShellInstance
  hidden [IAsyncResult]$AsyncHandle
  hidden [scriptblock]$ScriptBlock
  hidden [bool]$throwOnFail = $false
  [bool]$IsCancelled = $false
  [bool]$IsRunning = $false
  hidden [bool]$verbose = $((Get-Variable 'VerbosePreference' -ValueOnly) -eq 'Continue')
  hidden [int]$Index
  [JobResult]$Result

  BackgroundJob() {}
  BackgroundJob([hashtable]$job) {
    $job.Keys | ForEach-Object {
      switch ($_.ToLower()) {
        { $_ -in ("n", "name") } { $this.Name = $job[$_] }
        { $_ -in ("s", "script", "scriptblock") } { $this.ScriptBlock = $job[$_] }
        { $_ -in ("a", "arg", "args", "argument", "arguments") } { $this.Arguments = @($job[$_]) }
        { $_ -in ("t", "throw", "throwonfail") } { $this.throwOnFail = $job[$_] }
        { $_ -in ("v", "verbose") } { $this.verbose = $job[$_] }
      }
    }
  }
  BackgroundJob([scriptblock]$command) {
    $this.ScriptBlock = $command
  }
  BackgroundJob([scriptblock]$command, [object[]]$Argumentlist) {
    $this.ScriptBlock = $command
    $this.Arguments = $Argumentlist
  }
  BackgroundJob([int]$Index, [string]$Name, [ScriptBlock]$command, [object[]]$Argumentlist) {
    $this.Index = $Index
    $this.Name = if ($Name) { $Name } else { "Job $($Index.ToString("D2"))" }
    $this.ScriptBlock = $command
    $this.Arguments = $Argumentlist
    $this.Result = [JobResult]@{ Index = $Index; Name = $Name }
  }
}

class AsyncHandle {
  [Object]$AsyncState
  [WaitHandle]$AsyncWaitHandle = [System.Threading.AutoResetEvent]::new($false)
  [bool]$CompletedSynchronously = $false
  [bool]$IsCompleted = $false
  hidden $value
  AsyncHandle() {}
  AsyncHandle($object) {
    $object.PsObject.Properties.Foreach({ $this.($_.Name) = $o.($_.Name) })
    $this.value = $object
  }
}

class AsyncResult : System.IAsyncResult {
  hidden [PowerShell] $Instance
  hidden [AsyncHandle] $Handle = [AsyncHandle]::new()
  AsyncResult() { }
  AsyncResult($object) {
    if (!$object.Instance) {
      throw [InvalidOperationException]::new('No Async instance found on object!')
    }
    if (!$object.AsyncHandle) {
      throw [InvalidOperationException]::new('No AsyncHandle found on object!')
    }
    $this.Instance = ([ref]$object.Instance).Value
    $this.Handle = ([ref]$object.AsyncHandle).Value
  }
  [JobResult[]] EndInvoke() {
    return $this.EndInvoke($false)
  }
  [JobResult[]] EndInvoke([bool]$Dispose) {
    if ($null -eq $this.Instance) {
      throw [InvalidOperationException]::new('No Async instance found! Run [PsRunner]::RunAsync($Jobs) and try again.')
    }
    $res = $this.Instance.EndInvoke($this.Handle.value)
    $this.Handle.IsCompleted = $true
    if ($Dispose) {
      if ([PsRunner].SyncHash["Instance"]) {
        if ([PsRunner].SyncHash["Instance"].Runspace.Name -eq $this.Instance.Runspace.Name) {
          [PsRunner].SyncHash["Instance"] = $null
        }
      }
      $this.Instance.Dispose()
    }
    return $res
  }
  hidden [bool] get_IsCompleted() {
    return $this.Handle.IsCompleted
  }
  hidden [WaitHandle] get_AsyncWaitHandle() {
    return $this.Handle.AsyncWaitHandle
  }
  hidden [object] get_AsyncState() {
    return $this.Instance.InvocationStateInfo.State
  }
  hidden [bool] get_CompletedSynchronously() {
    return $this.Handle.CompletedSynchronously
  }
  [void] Dispose() {
    $this.Instance.Dispose()
  }
  [string] ToString() { return '[{0}] {1}' -f $this.AsyncState, $this.Handle.value }
}

class ProgressTheme {
  [ConsoleColor]$BarColor
  [ConsoleColor]$CompletedColor
  [ConsoleColor]$RunningColor
  [ConsoleColor]$FailedColor
  [ConsoleColor]$PendingColor
  [ConsoleColor]$TextColor
  [ConsoleColor]$HeaderColor
  [ConsoleColor]$BorderColor
  [string]$TwirlFrames
  [string]$BarFilled
  [string]$BarEmpty
  [string]$BarStart
  [string]$BarEnd
  static hidden [PsRecord] $config = @{
    DefaultProgressMsg = "Running background task"
    ProgressBarColor   = "LightSeaGreen"
    ProgressMsgColor   = "LightGoldenrodYellow"
    TwirlEmojis        = [PsRecord]@{
      modern  = "◰◳◲◱"
      scifi   = "◇◈◆"
      lunar   = "◐◓◑◒"
      otto    = "←↖↑↗→↘↓↙"
      glyph   = "⣾⣽⣻⢿⡿⣟⣯⣷" # black and white
      classic = "|/-\\"
      vintage = "-\\|/"
    }
  }

  static [ProgressTheme] $Modern = [ProgressTheme]::GetModern()
  static [ProgressTheme] $Scifi = [ProgressTheme]::GetScifi()
  static [ProgressTheme] $Lunar = [ProgressTheme]::GetLunar()
  static [ProgressTheme] $Otto = [ProgressTheme]::GetOtto()
  static [ProgressTheme] $Glyph = [ProgressTheme]::GetGlyph()
  static [ProgressTheme] $Classic = [ProgressTheme]::GetClassic()
  static [ProgressTheme] $Vintage = [ProgressTheme]::GetVintage()
  ProgressTheme() {}
  ProgressTheme([string]$Name) {
    $t = [scriptblock]::Create("[ProgressTheme]::Get$Name()").Invoke()
    $this.PsObject.Properties.Name | ForEach-Object { $this.$($_) = $t.$($_) }
  }
  static hidden [ProgressTheme] GetModern() {
    $t = [ProgressTheme]@{}
    $t.BarColor = "Cyan"; $t.CompletedColor = "Green"; $t.RunningColor = "Yellow"
    $t.FailedColor = "Red"; $t.PendingColor = "DarkGray"; $t.TextColor = "White"
    $t.HeaderColor = "Cyan"; $t.BorderColor = "DarkGray"
    $t.BarFilled = "█"; $t.BarEmpty = "░"; $t.BarStart = ""; $t.BarEnd = ""
    $t.TwirlFrames = [ProgressTheme]::config.TwirlEmojis.modern
    return $t
  }
  static hidden [ProgressTheme] GetScifi() {
    $t = [ProgressTheme]@{}
    $t.BarColor = "Cyan"; $t.CompletedColor = "Green"; $t.RunningColor = "Yellow"
    $t.FailedColor = "Red"; $t.PendingColor = "DarkGray"; $t.TextColor = "White"
    $t.HeaderColor = "Cyan"; $t.BorderColor = "DarkGray"
    $t.BarFilled = "▰"; $t.BarEmpty = "▱"; $t.BarStart = ""; $t.BarEnd = ""
    $t.TwirlFrames = [ProgressTheme]::config.TwirlEmojis.scifi
    return $t
  }
  static hidden [ProgressTheme] GetLunar() {
    $t = [ProgressTheme]@{}
    $t.BarColor = "Cyan"; $t.CompletedColor = "Green"; $t.RunningColor = "Yellow"
    $t.FailedColor = "Red"; $t.PendingColor = "DarkGray"; $t.TextColor = "White"
    $t.HeaderColor = "Cyan"; $t.BorderColor = "DarkGray"
    $t.BarFilled = "▩"; $t.BarEmpty = "▢"; $t.BarStart = ""; $t.BarEnd = ""
    $t.TwirlFrames = [ProgressTheme]::config.TwirlEmojis.lunar
    return $t
  }
  static hidden [ProgressTheme] GetOtto() {
    $t = [ProgressTheme]@{}
    $t.BarColor = "Cyan"; $t.CompletedColor = "Green"; $t.RunningColor = "Yellow"
    $t.FailedColor = "Red"; $t.PendingColor = "DarkGray"; $t.TextColor = "White"
    $t.HeaderColor = "Cyan"; $t.BorderColor = "DarkGray"
    $t.BarFilled = "¦"; $t.BarEmpty = " "; $t.BarStart = ""; $t.BarEnd = ""
    $t.TwirlFrames = [ProgressTheme]::config.TwirlEmojis.otto
    return $t
  }
  static hidden [ProgressTheme] GetGlyph() {
    $t = [ProgressTheme]@{}
    $t.BarColor = "Cyan"; $t.CompletedColor = "Green"; $t.RunningColor = "Yellow"
    $t.FailedColor = "Red"; $t.PendingColor = "DarkGray"; $t.TextColor = "White"
    $t.HeaderColor = "Cyan"; $t.BorderColor = "DarkGray"
    $t.BarFilled = "⣿"; $t.BarEmpty = " "; $t.BarStart = ""; $t.BarEnd = ""
    $t.TwirlFrames = [ProgressTheme]::config.TwirlEmojis.glyph
    return $t
  }
  static hidden [ProgressTheme] GetClassic() {
    $t = [ProgressTheme]@{}
    $t.BarColor = "Cyan"; $t.CompletedColor = "Green"; $t.RunningColor = "Yellow"
    $t.FailedColor = "Red"; $t.PendingColor = "DarkGray"; $t.TextColor = "White"
    $t.HeaderColor = "Yellow"; $t.BorderColor = "DarkCyan"
    $t.BarFilled = "■"; $t.BarEmpty = " "; $t.BarStart = "["; $t.BarEnd = "]"
    $t.TwirlFrames = [ProgressTheme]::config.TwirlEmojis.classic
    return $t
  }
  static hidden [ProgressTheme] GetVintage() {
    $t = [ProgressTheme]@{}
    $t.BarColor = "Cyan"; $t.CompletedColor = "Green"; $t.RunningColor = "Yellow"
    $t.FailedColor = "Red"; $t.PendingColor = "DarkGray"; $t.TextColor = "White"
    $t.HeaderColor = "Cyan"; $t.BorderColor = "DarkGray"
    $t.BarFilled = "❚"; $t.BarEmpty = " "; $t.BarStart = ""; $t.BarEnd = ""
    $t.TwirlFrames = [ProgressTheme]::config.TwirlEmojis.vintage
    return $t
  }
}


class JobRunnerOptions {
  [string]$JobsTitle = "Running Background Tasks"
  [int]$LeftPadding = 2
  [int]$ProgressBarWidth = 40
  [ValidateNotNull()][ProgressTheme]$Theme = "Classic"
  [int]$MaxDegreeOfParallelism = [Environment]::ProcessorCount
  [ConsoleCoordinate]$StartPosition
  hidden [Mutex]$Mutex = [Mutex]::new($false, "ParallelProgressMutex_$(Get-Random)")
  hidden [ErrorLog]$ErrorLog = [ErrorLog]::new()

  [string] FormatTime([System.Diagnostics.Stopwatch]$Stopwatch) {
    if ($null -eq $Stopwatch -or $null -eq $Stopwatch.Elapsed) { return "00.0" }
    $ts = $Stopwatch.Elapsed
    if ($ts.TotalHours -ge 1) { return $ts.ToString("h\:mm\:ss") }
    elseif ($ts.TotalMinutes -ge 1) { return $ts.ToString("mm\:ss\.f") }
    else { return $ts.ToString("ss\.f") }
  }

  [void] UpdateProgressDisplay([BackgroundJob]$Job) {
    $this.Mutex.WaitOne() | Out-Null
    try {
      $cursorY = $this.StartPosition.Y + $Job.Index
      if ($cursorY -lt 0) { $cursorY = 0 }
      if ($cursorY -ge [Console]::BufferHeight) { $cursorY = [Console]::BufferHeight - 1 }
      [Console]::SetCursorPosition($this.StartPosition.X, $cursorY)

      $barFilled = [int]($Job.Progress / 100 * $this.ProgressBarWidth)
      $barFilled = [Math]::Max(0, [Math]::Min($barFilled, $this.ProgressBarWidth))
      $barEmpty = $this.ProgressBarWidth - $barFilled

      $filledStr = $this.Theme.BarFilled * $barFilled
      $emptyStr = $this.Theme.BarEmpty * $barEmpty

      $indexStr = $Job.Index.ToString("D2")
      $nameStr = if ($Job.Name.Length -gt 20) { $Job.Name.Substring(0, 17) + "..." } else { $Job.Name.PadRight(20) }
      $progressStr = $Job.Progress.ToString("F1").PadLeft(6) + "%"

      # Synchronous Twirl Generation based on TickCount
      $statusStr = $Job.Status
      if ($Job.Status -eq "Running") {
        $idx = [Math]::Floor([Environment]::TickCount / 100) % $this.Theme.TwirlFrames.Length
        $statusStr = "Running $($this.Theme.TwirlFrames[$idx])"
      }
      $statusStr = $statusStr.PadRight(12)

      $statusColor = switch ($Job.Status) {
        "Completed" { $this.Theme.CompletedColor; break }
        "Running" { $this.Theme.RunningColor; break }
        "Failed" { $this.Theme.FailedColor; break }
        default { $this.Theme.PendingColor }
      }
      # todo: use write-console cmdlet and use one of these colors: [ValidateScript( { return [bool][RGB]$_ })][string]$msgColor
      Write-Host "`r$(' ' * $this.LeftPadding)" -NoNewline
      Write-Host "[$indexStr]" -NoNewline -ForegroundColor DarkGray
      Write-Host " $nameStr " -NoNewline -ForegroundColor $this.Theme.TextColor

      if ($barFilled -gt 0) {
        Write-Host $this.Theme.BarStart -NoNewline -ForegroundColor $this.Theme.BorderColor
        Write-Host $filledStr -NoNewline -ForegroundColor $this.Theme.BarColor
        if ($barEmpty -gt 0) { Write-Host $emptyStr -NoNewline -ForegroundColor $this.Theme.BorderColor }
        Write-Host $this.Theme.BarEnd -NoNewline -ForegroundColor $this.Theme.BorderColor
      } else {
        Write-Host "$($this.Theme.BarStart)$emptyStr$($this.Theme.BarEnd)" -NoNewline -ForegroundColor $this.Theme.BorderColor
      }

      Write-Host " $progressStr " -NoNewline -ForegroundColor $this.Theme.TextColor
      Write-Host " $statusStr" -NoNewline -ForegroundColor $statusColor
      Write-Host " $($Job.ElapsedTime)" -NoNewline -ForegroundColor DarkGray
      Write-Host "      " -NoNewline
    } finally {
      $this.Mutex.ReleaseMutex()
    }
  }

  [void] LogErrors([PSDataCollection[ErrorRecord]]$ErrorRecords, [ErrorMetadata]$metadata, [bool]$throw) {
    if ($ErrorRecords.count -eq 0) { return }
    !$this.ErrorLog ? ($this.ErrorLog = [ErrorLog]::New()) : $null;
    $ErrorRecords.ForEach({
        $metadata.IsPrinted = !$throw
        $_.PsObject.Properties.Add([PSNoteProperty]::New("Metadata", $metadata))
        [void]$this.ErrorLog.Add($_)
      }
    )
    $throw ? (throw $ErrorRecords) : $($ErrorRecords | Out-String | Write-Console -f LightCoral)
  }
}



<#
# ThreadRunner Usage:
# .SYNOPSIS
#   ThreadRunner is basically a Parallel Jobs Tracker and runner with Real-time ASCII Progress Bars and Config Management.
#   [ThreadRunner]::Run
#     OverloadDefinitions
#     ------------------ -
#     static JobResult[] Run(hashtable[] Jobs)
#     static JobResult[] Run(ParallelJob[] Jobs)
#     static JobResult[] Run(string ActivityTitle, hashtable[] Jobs)
#     static JobResult[] Run(string ActivityTitle, ParallelJob[] Jobs)
#     static JobResult[] Run(string ActivityTitle, scriptblock command, System.Object[] argumentlist)
#     static JobResult[] Run(string ActivityTitle, System.Object[] Jobs, int MaxParallel, string Theme)
#     static JobResult[] Run(string ActivityTitle, scriptblock command, string MoreInfo, System.Object[] argumentlist)
#     static JobResult[] Run(string ActivityTitle, scriptblock command, string MoreInfo, System.Object[] argumentlist, bool throwOnFail, bool verbose)
# .DESCRIPTION
#   A comprehensive module combining thread-safe Mutex-driven real-time progress bars with
#   high-performance Runspace pools. Features include:
#   - High-performance Parallel execution using RunspacePools
#   - Real-time cursor positioning for live updates
#   - Animated progress bars with synchronous multi-bar twirling
#   - Full error, state, and activity management (ErrorLog, ActivityLog)
#   - Configuration management via PsRecord (now with standard AES encryption)
.EXAMPLE
  ## run multiple jobs in parallel:
  $Jobs = [BackgroundJob[]](
      @{
        Name        = "Compute Primes"
        ScriptBlock = {
          param($count)
          $primes = @(2)
          $n = 3
          while ($primes.Count -lt $count) {
            $isPrime = $true
            foreach ($p in $primes) {
              if (($p * $p) -gt $n) { break }
              if ($n % $p -eq 0) {
                $isPrime = $false
                break
              }
            }
            if ($isPrime) { $primes += $n }
            $n += 2
          }
          return @{
            Count     = $primes.Count
            LastPrime = $primes[-1]
          }
        }
        Arguments   = @(2500)
      },
      @{
        Name        = "Simulate File Processing"
        ScriptBlock = {
          param($fileCount)
          $files = @()
          for ($i = 1; $i -le $fileCount; $i++) {
            $files += "file_$i.txt"
            Start-Sleep -Milliseconds 60
          }
          return @{
            Processed = $files.Count
            Files     = $files[0..3]
          }
        }
        Arguments   = @(30)
      },
      @{
        Name        = "Simulate API Calls"
        ScriptBlock = {
          param($callCount)
          $results = @()
          for ($i = 1; $i -le $callCount; $i++) {
            $results += @{
              Call    = $i
              Status  = "Success"
              Latency = Get-Random -Minimum 50 -Maximum 200
            }
            Start-Sleep -Milliseconds 100
          }
          return $results
        }
        Arguments   = @(15)
      },
      @{
        n = "Data Analysis"
        s = {
          param($iterations)
          $data = @()
          $sum = 0
          for ($i = 1; $i -le $iterations; $i++) {
            $value = Get-Random -Minimum 1 -Maximum 100
            $data += $value
            $sum += $value
            Start-Sleep -Milliseconds 20
          }
          $avg = $sum / $data.Count
          return @{
            TotalRecords = $data.Count
            Average      = [Math]::Round($avg, 2)
          }
        }
        a = @(100)
        t = $false
      },
      @{
        Name        = "DB Operations (Fails)"
        ScriptBlock = {
          param($operationCount)
          Start-Sleep -Milliseconds 500
          throw "Connection to database failed randomly."
        }
        Arguments   = @(15)
      }
    )

    $results = [ThreadRunner]::Run("Doing epic stuff in the background...", $Jobs)

.EXAMPLE
  ## run just one job but with a custom activity title:
  [ThreadRunner]::Run("doing a failing task in the background...", @{
        n = "run fake db operations"
        s = {
          param($operationCount)
          Start-Sleep -Milliseconds 4000
          throw "idk wtf just happened!"
        }
        a = 15
        ThrowOnFail = $false
      }
    )
.EXAMPLE
  ## run multiple scriptblocks in parallel:
  [ThreadRunner]::Run("Doing epic stuff in the background...", {
      param($operationCount)
      1..$operationCount | ForEach-Object {
        Start-Sleep -Milliseconds 600
      }
      throw "idk wtf just happened!"
    },
    10
  )
.EXAMPLE
  $jobs = [BackgroundJob[]](
    @{
        n = "calc~Primes"
        s = { param($n) (1..$n | Where-Object { $_ -gt 1 -and (1..[Math]::Sqrt($_)) -notcontains $_ -or $_ -eq 2 }).Count }
        a = 1000
    },
    @{
        n = "Fibonacci"
        s = { param($n) $a, $b = 0, 1; 1..$n | ForEach-Object { $c = $a; $a = $b; $b = $c + $b; $a } }
        a = 20
    }
  )
  $results = [ThreadRunner]::Run("", $jobs, 2, "Classic")
.NOTES
    Author: alain herve
    Version: 2.0.0
    Requires: PowerShell 7+

  # Troubleshooting:
  # Progress bars aren't filling up linearly?
  Background jobs in PowerShell don't inherently emit percentage progress to the caller natively without complex event handling. `ProgressUtil` creates a smooth simulation based on the `IsRunning` state, while catching the exact moment jobs complete or fail.

  # Jobs stuck "Running"?
  Check if your script block contains infinite loops, `Read-Host` prompts, or commands waiting for user input. Background runspaces do not have interactive consoles and will hang indefinitely.

  # Out of Memory?
  PowerShell jobs spin up separate background processes (`pwsh`). Processing huge datasets in memory inside many concurrent jobs will consume RAM rapidly.
  - Reduce `$MaxParallel`.
  - Process data pipelines iteratively instead of storing them completely in variables.
#>

class ThreadRunner {
  static [string] $caller = '[ThreadRunner]'
  static [string] $Module = 'clihelper.core'
  hidden [int] $_MinThreads = 2
  hidden [int] $_MaxThreads = [ThreadRunner]::GetThreadCount()

  [JobRunnerOptions]$Options
  hidden [List[BackgroundJob]]$Jobs
  hidden [List[BackgroundJob]]$CompletedJobs
  hidden [bool]$CancellationRequested = $false
  static [ActivityLog]$ActivityLog = [ActivityLog]::new()

  ThreadRunner() {
    $this.Options = [JobRunnerOptions]::new()
    $this.Jobs = [List[BackgroundJob]]::new()
    $this.CompletedJobs = [List[BackgroundJob]]::new()
  }

  static [JobResult[]] Run([hashtable[]]$Jobs) {
    return [ThreadRunner]::Run([BackgroundJob[]]$Jobs)
  }
  static [JobResult[]] Run([BackgroundJob[]]$Jobs) {
    return [ThreadRunner]::Run("", $Jobs, [Environment]::ProcessorCount, "")
  }
  static [JobResult[]] Run([string]$ActivityTitle, [hashtable[]]$Jobs) {
    return [ThreadRunner]::Run($ActivityTitle, [BackgroundJob[]]$Jobs)
  }
  static [JobResult[]] Run([string]$ActivityTitle, [BackgroundJob[]]$Jobs) {
    return [ThreadRunner]::Run($ActivityTitle, $Jobs, [Environment]::ProcessorCount, "")
  }
  static [JobResult[]] Run([string]$ActivityTitle, [scriptblock]$command, [object[]]$argumentlist) {
    return [ThreadRunner]::Run($ActivityTitle, @([BackgroundJob]::new($command, $argumentlist)), 1, "")
  }
  static [JobResult[]] Run([string]$ActivityTitle, [BackgroundJob[]]$Jobs, [int]$MaxParallel, [string]$Theme) {
    if ($null -eq $Jobs) { throw [System.ArgumentNullException]::new("Jobs") }
    if ($MaxParallel -le 0) { throw [System.ArgumentOutOfRangeException]::new("MaxParallel") }
    $validThemes = ([ProgressTheme] | Get-Member -Type Properties -Static).Name
    $threadRunner = [ThreadRunner]::new()
    if (![string]::IsNullOrWhiteSpace($Theme)) {
      if ($Theme -notin $validThemes) {
        throw [ArgumentException]::new("Theme is not valid. Use one of the following: " + ($validThemes -join ", "))
      } else {
        $threadRunner.Options.Theme = $Theme
      }
    }
    $threadRunner.Options.MaxDegreeOfParallelism = $MaxParallel
    $threadRunner.Options.JobsTitle = if ([string]::IsNullOrWhiteSpace($ActivityTitle)) { "Running Background Tasks" } else { $ActivityTitle }
    foreach ($job in $Jobs) {
      if ($job -is [hashtable]) { $job = [BackgroundJob]::new($job) }
      $arg = if ($null -ne $job.Arguments -and $job.Arguments.Count -gt 0) { $job.Arguments[0] } else { $null }
      $threadRunner.AddJob($job.Name, $job.ScriptBlock, $arg)
    }
    return $threadRunner.ExecuteAll()
  }
  static [JobResult[]] Run([string]$ActivityTitle, [scriptblock]$command, [string]$MoreInfo, [object[]]$argumentlist) {
    return [ThreadRunner]::Run($ActivityTitle, $command, $MoreInfo, $argumentlist, $false, ((Get-Variable 'VerbosePreference' -ValueOnly) -eq 'Continue'))
  }
  static [JobResult[]] Run([string]$ActivityTitle, [scriptblock]$command, [string]$MoreInfo, [object[]]$argumentlist, [bool]$throwOnFail, [bool]$verbose) {
    # .EXAMPLE
    # $result = [ThreadRunner]::Run("Making guid & some background stuff", { param([string]$str) Start-Sleep 3; return ($str | xconvert ToGuid) }, "some text")
    return [ThreadRunner]::Run($ActivityTitle, @{
        n = [string]::IsNullOrWhiteSpace($MoreInfo) ? ([ProgressTheme]::config.DefaultProgressMsg) : $MoreInfo
        s = $command
        a = $argumentlist ? $argumentlist : @()
        t = $throwOnFail
        v = $verbose
      }
    )
  }

  [void] AddJob([string]$Name, [ScriptBlock]$ScriptBlock, [object]$Argument) {
    $this.Jobs.Add([BackgroundJob]::new($this.Jobs.Count, $Name, $ScriptBlock, $Argument))
  }

  [string] FormatTime([System.Diagnostics.Stopwatch]$Stopwatch) {
    return $this.Options.FormatTime($Stopwatch)
  }

  [void] UpdateProgressDisplay([BackgroundJob]$Job) {
    $this.Options.UpdateProgressDisplay($Job)
  }
  [JobResult[]] ExecuteAll() {
    return [ThreadRunner]::WaitJobs($this.Jobs, $this.Options)
  }
  static hidden [JobResult[]] WaitJobs([List[BackgroundJob]]$Jobs, [JobRunnerOptions]$opts) {
    $originalCursorVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false

    # Activity Logging
    $act = [Activity]::new($opts.JobsTitle)
    $act.Start()
    [ThreadRunner]::ActivityLog.Add([guid]::new($act.TraceId), $act)

    Write-Host "  $(' ' * $opts.LeftPadding)" -NoNewline
    Write-Host $opts.JobsTitle -ForegroundColor $opts.Theme.HeaderColor
    Write-Host "$(' ' * $opts.LeftPadding) ID    NAME                PROGRESS                         STATUS            TIME" -ForegroundColor DarkGray
    Write-Host ""

    $startY = [Console]::CursorTop
    for ($i = 0; $i -lt $Jobs.Count; $i++) { Write-Host "" }
    $opts.StartPosition = [ConsoleCoordinate]::new($opts.LeftPadding, $startY)

    foreach ($job in $Jobs) { $opts.UpdateProgressDisplay($job) }

    # Setup Runspace Pool
    $iss = [InitialSessionState]::CreateDefault()
    $pool = [RunspaceFactory]::CreateRunspacePool(1, $opts.MaxDegreeOfParallelism, $iss, $(Get-Variable Host).Value)
    $pool.Open()

    $results = [List[JobResult]]::new()
    $runningJobs = [List[BackgroundJob]]::new()
    $jobQueue = [Queue[BackgroundJob]]::new($Jobs)

    while ($jobQueue.Count -gt 0 -or $runningJobs.Count -gt 0) {
      # Dequeue and start up to MaxDegreeOfParallelism
      while ($runningJobs.Count -lt $opts.MaxDegreeOfParallelism -and $jobQueue.Count -gt 0) {
        $job = $jobQueue.Dequeue()
        $job.IsRunning = $true
        $job.Status = "Starting"
        $job.Stopwatch.Start()

        $ps = [PowerShell]::Create()
        $ps.RunspacePool = $pool
        $ps.AddScript($job.ScriptBlock) | Out-Null
        if ($null -ne $job.Argument) { $ps.AddArgument($job.Argument) | Out-Null }

        $job.PowerShellInstance = $ps
        $job.AsyncHandle = $ps.BeginInvoke()
        $runningJobs.Add($job)
      }

      # Monitor Running Jobs
      for ($i = $runningJobs.Count - 1; $i -ge 0; $i--) {
        $job = $runningJobs[$i]
        $job.ElapsedTime = $opts.FormatTime($job.Stopwatch)

        if ($job.AsyncHandle.IsCompleted) {
          $job.Stopwatch.Stop()
          $job.IsRunning = $false
          try {
            $output = $job.PowerShellInstance.EndInvoke($job.AsyncHandle)
            if ($job.PowerShellInstance.HadErrors) {
              $job.Status = "Failed"
              $job.Result.Success = $false
              $errors = $job.PowerShellInstance.Streams.Error
              $job.Result.Error = $errors[0].Exception.Message # show the last error message
              $MoreAbouttheError = $errors[0] | Format-List * -Force | Out-String
              $ErrorRecords = [PSDataCollection[ErrorRecord]]::new(); $errors.ForEach({ $ErrorRecords.Add($_) })
              $opts.LogErrors($ErrorRecords, [ThreadRunner]::GetErrorMetadata($ErrorRecords, $MoreAbouttheError), $job.ThrowOnFail)
            } else {
              $job.Progress = 100
              $job.Status = "Completed"
              $job.Result.Success = $true
              $job.Result.Output = if ($output.Count -eq 1) { $output[0] } else { $output }
            }
          } catch {
            $job.Status = "Failed"
            $job.Result.Success = $false
            $job.Result.Error = $_.Exception.Message
          }
          $job.Result.DurationMs = $job.Stopwatch.ElapsedMilliseconds
          $job.Result.Stopwatch = $job.Stopwatch

          $job.PowerShellInstance.Dispose()
          $runningJobs.RemoveAt($i)
          $results.Add($job.Result)
        } else {
          # Simulate progress if not 100
          if ($job.Progress -lt 95) { $job.Progress = [Math]::Min($job.Progress + (Get-Random -Min 1 -Max 5), 95) }
          $job.Status = "Running"
        }
        $opts.UpdateProgressDisplay($job)
      }
      # Update Tick ensures fluid twirling
      Start-Sleep -Milliseconds 80
    }

    $pool.Close()
    $pool.Dispose()
    $act.Stop()

    $endY = $opts.StartPosition.Y + $Jobs.Count
    if ($endY -lt 0) { $endY = 0 }
    if ($endY -ge [Console]::BufferHeight) { $endY = [Console]::BufferHeight - 1 }
    [Console]::SetCursorPosition(0, $endY)
    [Console]::CursorVisible = $originalCursorVisible

    return $results.ToArray()
  }

  [void] LogErrors([PSDataCollection[ErrorRecord]]$ErrorRecords) {
    $this.LogErrors($ErrorRecords, [string]::Empty)
  }
  [void] LogErrors([PSDataCollection[ErrorRecord]]$ErrorRecords, [string]$MoreInfo) {
    $this.LogErrors($ErrorRecords, [ThreadRunner]::GetErrorMetadata($ErrorRecords, $MoreInfo))
  }
  [void] LogErrors([PSDataCollection[ErrorRecord]]$ErrorRecords, [ErrorMetadata]$metadata) {
    $this.LogErrors($ErrorRecords, $metadata, $false)
  }
  [void] LogErrors([PSDataCollection[ErrorRecord]]$ErrorRecords, [ErrorMetadata]$metadata, [bool]$throw) {
    $this.Options.LogErrors($ErrorRecords, $metadata, $throw)
  }
  static [int] GetThreadCount() {
    $_PID = Get-Variable PID -ValueOnly
    return $(if ((Get-Variable IsLinux, IsMacOs).Value -contains $true) { [scriptblock]::Create("gps huH p $_PID | wc --lines").Invoke() } else { $(Get-Process -Id $_PID).Threads.Count })
  }
  static [ErrorMetadata] GetErrorMetadata([PSDataCollection[ErrorRecord]]$ErrorRecords) {
    return [ThreadRunner]::GetErrorMetadata($ErrorRecords, [string]::Empty)
  }
  static [ErrorMetadata] GetErrorMetadata([PSDataCollection[ErrorRecord]]$ErrorRecords, [string]$MoreInfo) {
    return [ErrorMetadata]@{
      Timestamp      = [DateTime]::Now
      User           = $env:USER
      Module         = [ProgressUtil]::Module
      Severity       = 1
      StackTrace     = (($ErrorRecords.ScriptStackTrace | Out-String) + ' ').TrimEnd()
      AdditionalInfo = $MoreInfo + (($ErrorRecords.InvocationInfo.PositionMessage | Out-String) + ' ').TrimEnd()
    }
  }
}


<#
.SYNOPSIS
  PsRunner class
.DESCRIPTION
  Provides simple powerhsell multithreading implementation ie: Concurrent execution of multible jobs.
.NOTES
  Register-EngineEvent -SourceIdentifier ([System.Management.Automation.PsEngineEvent]::Exiting) -Action ([PsRunner]::GetOnRemovalScript())

 .EXAMPLE
  $jobs = (
    { $res = "worker running on thread $([Threading.Thread]::CurrentThread.ManagedThreadId)"; Start-Sleep -Seconds 1; return $res },
    { return (Get-Variable PsRunner_* -ValueOnly) },
    { $res = "worker running on thread $([Threading.Thread]::CurrentThread.ManagedThreadId)"; 10..20 | Get-Random | ForEach-Object {  Start-Sleep -Milliseconds ($_ * 100) }; return $res }
  )
  # sync:
  # $res = [PsRunner]::Run($jobs)
  # this is the same as using
  # $res = [ThreadRunner]::Run($jobs)

  # Async:
  $handle = [PsRunner]::RunAsync($jobs);
  Write-Host "we can do other stuff that we want ex: lets just wait" -ForegroundColor Cyan
  # ... run what you want here
  $result = $handle.EndInvoke($true)

 .EXAMPLE
  $ps = [powershell]::Create([PsRunner]::CreateRunspace())
  $ps = $ps.AddScript({
    $(Get-Variable SyncHash -ValueOnly)["JobsCleanup"] = "hello from rs manager"
    return [PSCustomObject]@{
      Setup    = Get-Variable RunSpace_Setup -ValueOnly
      SyncHash = Get-Variable SyncHash -ValueOnly
    }
  })
 $h = $ps.BeginInvoke()
 $ps.EndInvoke($h)
#>

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidAssignmentToAutomaticVariable', '', Justification = 'False flag. ie: $Sender and $EventArgs')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '', Justification = 'Its by design. iex is used to prepare new runspace')]
class PsRunner : ThreadRunner {
  static [string] $caller = '[PsRunner]'
  static [string] $SyncId = { [void][PsRunner]::SetSyncHash(); return [PsRunner].SyncId }.Invoke() # Unique ID for each runner instance
  static [AsyncResult] $AsyncResult = [AsyncResult]::new()

  static PsRunner() {
    # set properties (Once-time)
    "PsRunner" | Update-TypeData -MemberName Id -MemberType ScriptProperty -Value { return [PsRunner]::SyncId } -SecondValue { throw [SetValueException]::new('Id is read-only') } -Force;
    "PsRunner" | Update-TypeData -MemberName MinThreads -MemberType ScriptProperty -Value { return $this._MinThreads } -SecondValue {
      if ($value -lt 2) { throw [ArgumentOutOfRangeException]::new("MinThreads must be greater than or equal to 2") };
      $this._MinThreads = $value
    } -Force;
    "PsRunner" | Update-TypeData -MemberName MaxThreads -MemberType ScriptProperty -Value { return $this._MaxThreads } -SecondValue {
      $m = [ThreadRunner]::GetThreadCount(); if ($value -gt $m) { throw [ArgumentOutOfRangeException]::new("MaxThreads must be less than or equal to $m") }
      $this._MaxThreads = $value
    } -Force;
    [PsRunner].PsObject.Properties.Add([PSScriptProperty]::new('Instance', {
          if (![PsRunner]::GetSyncHash()["Instance"]) { [PsRunner].SyncHash["Instance"] = [PsRunner]::Create_runspace_manager() };
          return [PsRunner].SyncHash["Instance"]
        }, {
          throw [SetValueException]::new('Instance is read-only')
        }
      )
    )
    "PsRunner" | Update-TypeData -MemberName GetOutput -MemberType ScriptMethod -Value {
      $o = [PsRunner]::GetSyncHash()["Output"]; [PsRunner].SyncHash["Output"] = [System.Management.Automation.PSDataCollection[PsObject]]::new()
      [PsRunner].SyncHash["Runspaces"] = [ConcurrentDictionary[int, PowerShell]]::new()
      return $o
    } -Force;
  }
  static [AsyncResult] RunAsync() {
    if (![PsRunner]::HasPendingJobs()) {
      throw [InvalidOperationException]::new("There are no pending jobs. Hint: run Add_BGWorker({ScriptBlock}); then try again.")
    }
    return [PsRunner]::RunAsync([PsRunner]::GetSyncHash()["Runspaces"])
  }
  static [AsyncResult] RunAsync([scriptblock[]]$Jobs) {
    if ([PsRunner]::HasPendingJobs()) {
      throw [InvalidOperationException]::new('PsRunner has pending Jobs; either run them or run ::CleanUp() first')
    }
    [PsRunner]::CleanUp(); $Jobs.ForEach({ [PsRunner]::Add_BGWorker($_) })
    return [PsRunner]::RunAsync([PsRunner]::GetSyncHash()["Runspaces"])
  }
  static [AsyncResult] RunAsync([ConcurrentDictionary[int, PowerShell]]$Runspaces) {
    # .SYNOPSIS
    # Run asynchronously
    # .DESCRIPTION
    # Offloads work of long-running processe. designed to execute heavy operations in the background to avoid interfering with main application thread.
    [PsRunner]::GetSyncHash()["Runspaces"] = $Runspaces
    [PsRunner]::AsyncResult.Handle = [IAsyncResult][PsRunner].Instance.BeginInvoke()
    [PsRunner]::AsyncResult.Instance = [PsRunner].Instance
    return [PsRunner]::AsyncResult
  }
  static [JobResult[]] WaitJobs([scriptblock[]]$Jobs) {
    $handle = [PsRunner]::RunAsync($jobs);

    while ($handle.AsyncState -eq "Running") {
      Write-Host "." -NoNewline
      Start-Sleep -Milliseconds 100
    }
    $result = $handle.EndInvoke($true)

    return $result
  }
  static [PSDataCollection[PsObject]] EndInvoke() {
    return [PsRunner]::EndInvoke($true)
  }
  static [PSDataCollection[PsObject]] EndInvoke([bool]$Dispose) {
    if (![PsRunner]::AsyncResult) { throw "No AsyncResult result found" }
    return [PsRunner]::AsyncResult.EndInvoke($Dispose)
  }
  static [Runspace] CreateRunspace() {
    $defaultvars = @(
      [PSVariable]::new("RunSpace_Setup", [PsRunner]::GetRunSpace_Setup())
      [PSVariable]::new("SyncHash", [PsRunner]::GetSyncHash())
    )
    return [PsRunner]::CreateRunspace($defaultvars)
  }
  static [Runspace] CreateRunspace([PSVariable[]]$variables) {
    # https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables
    $automatic_variables = @('$', '?', '^', '_', 'args', 'ConsoleFileName', 'EnabledExperimentalFeatures', 'Error', 'Event', 'EventArgs', 'EventSubscriber', 'ExecutionContext', 'false', 'foreach', 'HOME', 'Host', 'input', 'IsCoreCLR', 'IsLinux', 'IsMacOS', 'IsWindows', 'LASTEXITCODE', 'Matches', 'MyInvocation', 'NestedPromptLevel', 'null', 'PID', 'PROFILE', 'PSBoundParameters', 'PSCmdlet', 'PSCommandPath', 'PSCulture', 'PSDebugContext', 'PSEdition', 'PSHOME', 'PSItem', 'PSScriptRoot', 'PSSenderInfo', 'PSUICulture', 'PSVersionTable', 'PWD', 'Sender', 'ShellId', 'StackTrace', 'switch', 'this', 'true')
    $_variables = [PsRunner]::GetVariables().Where({ $_.Name -notin $automatic_variables }); $r = [runspacefactory]::CreateRunspace()
    if ((Get-Variable PSVersionTable -ValueOnly).PSEdition -ne "Core") { $r.ApartmentState = "STA" }
    $r.ThreadOptions = "ReuseThread"; $r.Open()
    $variables.ForEach({ $r.SessionStateProxy.SetVariable($_.Name, $_.Value) })
    [void]$r.SessionStateProxy.Path.SetLocation((Resolve-Path ".").Path)
    $_variables.ForEach({ $r.SessionStateProxy.PSVariable.Set($_.Name, $_.Value) })
    return $r
  }
  static [RunspacePool] CreateRunspacePool([int]$minRunspaces, [int]$maxRunspaces, [string[]]$UserModules, [PSVariable[]]$UserVariables, [string[]]$UserSnapins, [ScriptBlock[]]$UserFunctions) {
    #If specified, add variables and modules/snapins to session state
    $sessionstate = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    if ($UserVariables.count -gt 0) {
      foreach ($Variable in $UserVariables) {
        $sessionstate.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $Variable.Name, $Variable.Value, $null) )
      }
    }
    if ($UserModules.count -gt 0) {
      foreach ($ModulePath in $UserModules) {
        $sessionstate.ImportPSModule($ModulePath)
      }
    }
    if ($UserSnapins.count -gt 0) {
      foreach ($PSSnapin in $UserSnapins) {
        [void]$sessionstate.ImportPSSnapIn($PSSnapin, [ref]$null)
      }
    }
    if ($UserFunctions.count -gt 0) {
      foreach ($FunctionDef in $UserFunctions) {
        $sessionstate.Commands.Add((New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $FunctionDef.Name, $FunctionDef.ScriptBlock))
      }
    }
    return [PsRunner]::CreateRunspacePool($minRunspaces, $maxRunspaces, $sessionstate, $(Get-Variable Host).Value)
  }
  static [RunspacePool] CreateRunspacePool([int]$minRunspaces, [int]$maxRunspaces, [initialsessionstate]$sessionstate, [Host.PSHost]$PsHost) {
    Write-Verbose "Creating runspace pool and session states"
    $runspacepool = [runspacefactory]::CreateRunspacePool($minRunspaces, $maxRunspaces, $sessionstate, $PsHost)
    if ((Get-Variable PSVersionTable -ValueOnly).PSEdition -ne "Core") { $runspacepool.ApartmentState = "STA" }
    $runspacepool.Open()
    return $runspacepool
  }
  static [bool] Isvalid_NewRunspaceId([int]$RsId) {
    return [PsRunner]::Isvalid_NewRunspaceId($RsId, $true)
  }
  static [bool] Isvalid_NewRunspaceId([int]$RsId, [bool]$ThrowOnFail) {
    $v = $null -eq (Get-Runspace -Id $RsId)
    if (!$v -and $ThrowOnFail) {
      throw [System.InvalidOperationException]::new("Runspace with ID $RsId already exists.")
    }; return $v
  }
  static [void] Add_BGWorker([ScriptBlock]$Worker) {
    [PsRunner]::Add_BGWorker([PsRunner]::GetWorkerId(), $Worker, @())
  }
  static [void] Add_BGWorker([int]$Id, [ScriptBlock]$Worker, [object[]]$Arguments) {
    [void][PsRunner]::Isvalid_NewRunspaceId($Id)
    $ps = [powershell]::Create([PsRunner]::CreateRunspace())
    $ps = $ps.AddScript($Worker)
    if ($Arguments.Count -gt 0) { $Arguments.ForEach({ [void]$ps.AddArgument($_) }) }
    # $ps.RunspacePool = [PsRunner].SyncHash["RunspacePool"] # https://github.com/PowerShell/PowerShell/issues/18934
    # Save each Worker in a dictionary, ie: {Int_Id, PowerShell_instance_on_different_thread}
    if (![PsRunner]::GetSyncHash()["Runspaces"].TryAdd($Id, $ps)) { throw [System.InvalidOperationException]::new("worker $Id already exists.") }
    [PsRunner].SyncHash["Jobs"][$Id] = @{
      __PS   = ([ref]$ps).Value
      Status = ([ref]$ps).Value.Runspace.RunspaceStateInfo.State
      Result = $null
    }
  }
  static [PSVariable[]] GetVariables() {
    # Set Environment Variables
    # if ($EnvironmentVariablesToForward -notcontains '*') {
    #   $EnvVariables = foreach ($obj in $EnvVariables) {
    #     if ($EnvironmentVariablesToForward -contains $obj.Name) {
    #       $obj
    #     }
    #   }
    # }
    # Write-Verbose "Setting SyncId <=> (OneTime/Session)"
    return (Get-Variable).Where({ $o = $_.Options.ToString(); $o -notlike "*ReadOnly*" -and $o -notlike "*Constant*" })
  }
  static [System.Management.Automation.FunctionInfo[]] GetCommands() {
    # if ($FunctionsToForward -notcontains '*') {
    #   $Functions = foreach ($FuncObj in $Functions) {
    #     if ($FunctionsToForward -contains $FuncObj.Name) {
    #       $FuncObj
    #     }
    #   }
    # }
    # $res = [PsRunner].SyncHash["Commands"]; if ($res) { return $res }
    return (Get-ChildItem Function:).Where({ ![System.String]::IsNullOrWhiteSpace($_.Name) })
  }
  static [string[]] GetModuleNames() {
    # if ($ModulesToForward -notcontains '*') {
    #   $Modules = foreach ($obj in $Modules) {
    #     if ($ModulesToForward -contains $obj.Name) {
    #       $obj
    #     }
    #   }
    # }
    return (Get-Module).Name
  }
  static [ArrayList] GetRunSpace_Setup() {
    return [PsRunner]::GetRunSpace_Setup((Get-ChildItem Env:), [PsRunner]::GetModuleNames(), [PsRunner]::GetCommands());
  }
  static [ArrayList] GetRunSpace_Setup([DictionaryEntry[]]$EnvVariables, [string[]]$ModuleNames, [Object[]]$Functions) {
    [ArrayList]$RunSpace_Setup = @(); $EnvVariables = Get-ChildItem Env:\
    $SetEnvVarsPrep = foreach ($obj in $EnvVariables) {
      if ([char[]]$obj.Name -contains '(' -or [char[]]$obj.Name -contains ' ') {
        $strr = @(
          'try {'
          $('  ${env:' + $obj.Name + '} = ' + "@'`n$($obj.Value)`n'@")
          '} catch {'
          "  Write-Debug 'Unable to forward environment variable $($obj.Name)'"
          '}'
        )
      } else {
        $strr = @(
          'try {'
          $('  $env:' + $obj.Name + ' = ' + "@'`n$($obj.Value)`n'@")
          '} catch {'
          "  Write-Debug 'Unable to forward environment variable $($obj.Name)'"
          '}'
        )
      }
      [string]::Join("`n", $strr)
    }
    [void]$RunSpace_Setup.Add([string]::Join("`n", $SetEnvVarsPrep))
    $Modules = Get-Module -Name $ModuleNames | Select-Object Name, @{ l = "Manifest"; e = { [IO.Path]::Combine($_.ModuleBase, $_.Name + ".psd1") } }
    $SetModulesPrep = foreach ($obj in $Modules) {
      $strr = @(
        '$tempfile = [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetRandomFileName())'
        "if (![bool]('$($obj.Name)' -match '\.WinModule')) {"
        ' try {'
        "   Import-Module '$($obj.Name)' -NoClobber -ErrorAction Stop 2>`$tempfile"
        '} catch {'
        '  try {'
        "   Import-Module '$($obj.Manifest)' -NoClobber -ErrorAction Stop 2>`$tempfile"
        '  } catch {'
        "   Write-Debug 'Unable to Import-Module $($obj.Name)'"
        '  }'
        ' }'
        '}'
        'if ([IO.File]::Exists($tempfile)) {'
        ' Remove-Item $tempfile -Force'
        '}'
      )
      [string]::Join("`n", $strr)
    }
    [void]$RunSpace_Setup.Add([string]::Join("`n", $SetModulesPrep))
    $SetFunctionsPrep = foreach ($obj in $Functions) {
      $_src_txt = '@(${Function:' + $obj.Name + '}.Ast.Extent.Text)'
      $FunctionText = [scriptblock]::Create($_src_txt).InvokeReturnAsIs()
      if ($($FunctionText -split "`n").Count -gt 1) {
        if ($($FunctionText -split "`n")[0] -match "^function ") {
          if ($($FunctionText -split "`n") -match "^'@") {
            Write-Debug "Unable to forward function $($obj.Name) due to heredoc string: '@"
          } else {
            'Invoke-Expression ' + "@'`n$FunctionText`n'@"
          }
        }
      } elseif ($($FunctionText -split "`n").Count -eq 1) {
        if ($FunctionText -match "^function ") {
          'Invoke-Expression ' + "@'`n$FunctionText`n'@"
        }
      }
    }
    [void]$RunSpace_Setup.Add([string]::Join("`n", $SetFunctionsPrep))
    return $RunSpace_Setup
  }
  static [Hashtable] SetSyncHash() {
    return [PsRunner]::SetSyncHash($False)
  }
  static [Hashtable] SetSyncHash([bool]$Force) {
    if (![PsRunner].SyncHash -or $Force) {
      $Id = [string]::Empty; $sv = Get-Variable PsRunner_* -Scope Global; if ($sv.Count -gt 0) { $Id = $sv[0].Name }
      if ([string]::IsNullOrWhiteSpace($Id)) { $Id = "PsRunner_{0}" -f [Guid]::NewGuid().Guid.substring(0, 21).replace('-', [string]::Join('', (0..9 | Get-Random -Count 1))) };
      [PsRunner].PsObject.Properties.Add([PSScriptProperty]::new('SyncId', [scriptblock]::Create("return '$Id'"), { throw [SetValueException]::new('SyncId is read-only') }))
      [PsRunner].PsObject.Properties.Add([PsNoteProperty]::new('SyncHash', [Hashtable]::Synchronized(@{
              Id          = [string]::Empty
              Jobs        = [Hashtable]::Synchronized(@{})
              Runspaces   = [ConcurrentDictionary[int, PowerShell]]::new()
              JobsCleanup = @{}
              Output      = [PSDataCollection[PsObject]]::new()
            }
          )
        )
      );
      New-Variable -Name $Id -Value $([ref][PsRunner].SyncHash).Value -Option AllScope -Scope Global -Visibility Public -Description "PID_$(Get-Variable PID -ValueOnly)_PsRunner_variables" -Force
      [PsRunner].SyncHash["Id"] = $Id;
    }
    return [PsRunner].SyncHash
  }
  static [PowerShell] Create_runspace_manager() {
    $i = [powershell]::Create([PsRunner]::CreateRunspace())
    $i.AddScript({
        $Runspaces = $SyncHash["Runspaces"]
        $Jobs = $SyncHash["Jobs"]
        if ($RunSpace_Setup) {
          foreach ($obj in $RunSpace_Setup) {
            if ([string]::IsNullOrWhiteSpace($obj)) { continue }
            try {
              Invoke-Expression -Command $obj
            } catch {
              throw ("Error {0} `n{1}" -f $_.Exception.Message, $_.ScriptStackTrace)
            }
          }
        }
        $Runspaces.Keys.ForEach({
            $Jobs[$_]["Handle"] = [IAsyncResult]$Jobs[$_]["__PS"].BeginInvoke()
            Write-Host "Started worker $_" -f Yellow
          }
        )
        # Monitor workers until they complete
        while ($Runspaces.ToArray().Where({ $Jobs[$_.Key]["Handle"].IsCompleted -eq $false }).count -gt 0) {
          # Write-Host "$(Get-Date) Still running..." -f Green
          # foreach ($worker in $Runspaces.ToArray()) {
          #   $Id = $worker.Key
          #   $status = $Jobs[$Id]["Status"]
          #   Write-Host "worker $Id Status: $status"
          # }
          Start-Sleep -Milliseconds 500
        }
        Write-Host "All workers are complete." -f Yellow
        $SyncHash["Results"] = @(); foreach ($i in $Runspaces.Keys) {
          $__PS = $Jobs[$i]["__PS"]
          try {
            $Jobs[$i] = @{
              Output = $__PS.EndInvoke($Jobs[$i]["Handle"])
              Status = "Completed"
            }
          } catch {
            $Jobs[$i] = @{
              Output = $_.Exception.Message
              Status = "Failed"
            }
          } finally {
            # Dispose of the PowerShell instance
            $__PS.Runspace.Close()
            $__PS.Runspace.Dispose()
            $__PS.Dispose()
          }
          # Store results
          $SyncHash["Results"] += @{
            Index   = $i
            Output  = $Jobs[$i]["Output"]
            Status  = $Jobs[$i]["Status"]
            Success = $Jobs[$i]["Status"] -ne "Failed"
          }
        }
        return $SyncHash["Results"]
      }
    )
    # $i.Runspace.Name += "RSM"
    return $i
  }
  static [hashtable] GetSyncHash() {
    return (Get-Variable -Name $([PsRunner]::SyncId) -ValueOnly -Scope Global)
  }
  static [bool] HasPendingJobs() {
    $j = [PsRunner]::GetSyncHash()["Jobs"]
    return (($j.count -gt 0) ? $j.Values.Keys.Contains("__PS") : $false)
  }
  static [void] CleanUp() {
    [PsRunner].SyncHash.Jobs.Clear()
    # [PsRunner].SyncHash["Instance"] = [PsRunner]::Create_runspace_manager()
    $rs = [PsRunner]::GetSyncHash()["Runspaces"]
    [PsRunner].SyncHash.Runspaces = [ConcurrentDictionary[int, PowerShell]]::new();
    $rs.keys.Where({ $rs[$_].InvocationStateInfo.State -ne "Completed" }).Foreach({ [PsRunner].SyncHash.Runspaces[$_] = $rs[$_] })
    if ([PsRunner].SyncHash.Results) { [PsRunner].SyncHash.Results = @() }
    if ([PsRunner].SyncHash.Output) { [PsRunner].SyncHash.Output = [PSDataCollection[PsObject]]::new() }
  }
  static [int] GetWorkerId() {
    $Id = 0; do {
      $Id = ((Get-Runspace).Id)[-1] + 1
    } until ([PsRunner]::Isvalid_NewRunspaceId($Id, $false))
    return $Id
  }
}

