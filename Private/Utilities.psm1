
using module .\Enums.psm1
using module .\Abstracts.psm1
using module .\Console\Colors.psm1
using module .\Console.psm1
using module .\Console\Internal.psm1
using module .\Result.psm1

class FileTools {
  static [PSObject] GetItemSize([string]$Path) {
    $size = 0
    if (Test-Path $Path -PathType Container -ErrorAction SilentlyContinue) {
      $size = Get-ChildItem -Path $Path -File -Recurse -Force | Measure-Object -Property Length -Sum | Select-Object -ExpandProperty sum
    } else {
      $size = Get-Item -Path $Path | Select-Object -ExpandProperty Length
    }
    return [PSCustomObject] @{ bytes = $size; Item = Get-Item $Path }
  }
  static [string] GetShortPath([string]$Path, [int]$KeepBefore, [int]$KeepAfter, [string]$Separator, [string]$TruncateChar) {
    $splitPath = $Path.Split($Separator, [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($splitPath.Count -gt ($KeepBefore + $KeepAfter)) {
      $outPath = [string]::Empty
      for ($i = 0; $i -lt $KeepBefore; $i++) { $outPath += $splitPath[$i] + $Separator }
      $outPath += "$($TruncateChar)$($Separator)"
      for ($i = ($splitPath.Count - $KeepAfter); $i -lt $splitPath.Count; $i++) {
        if ($i -eq ($splitPath.Count - 1)) { $outPath += $splitPath[$i] } else { $outPath += $splitPath[$i] + $Separator }
      }
    } else {
      $outPath = $splitPath -join $Separator
      if ($splitPath.Count -eq 1) { $outPath += $Separator }
    }
    return $outPath
  }
  static [string] GetShortPath([string]$Path) {
    return [FileTools]::GetShortPath($Path, 2, 1, [System.IO.Path]::DirectorySeparatorChar, [char]8230)
  }
  static [string] NewRandomFileName([string]$Extension, [bool]$UseTempFolder, [bool]$UseHomeFolder) {
    if ($UseTempFolder) { $filename = [system.io.path]::GetTempFileName() }
    elseif ($UseHomeFolder) {
      $homedocs = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
      $filename = Join-Path -Path $homedocs -ChildPath ([system.io.path]::GetRandomFileName())
    } else { $filename = [system.io.path]::GetRandomFileName() }

    if (![string]::IsNullOrEmpty($Extension)) {
      $original = [system.io.path]::GetExtension($filename).Substring(1)
      return $filename -replace "$original$", $Extension
    }
    return $filename
  }
  static [string] GetTempDirectory() {
    return [System.IO.Path]::GetTempPath()
  }
  static [string] GetHomeDirectory() {
    return [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
  }
}


class HashTools {
  static [hashtable] JoinHashtable([hashtable]$First, [hashtable]$Second, [bool]$Force) {
    $Primary = $First.Clone()
    $Secondary = $Second.Clone()
    $duplicates = $Primary.keys | Where-Object { $Secondary.ContainsKey($_) }
    if ($duplicates) {
      foreach ($item in $duplicates) {
        if ($Force) {
          $Secondary.Remove($item)
        } else {
          $r = Read-Host "Which key do you want to KEEP [AB]?"
          if ($r -eq "A") { $Secondary.Remove($item) }
          elseif ($r -eq "B") { $Primary.Remove($item) }
          else { Write-Warning "Aborting"; return $null }
        }
      }
    }
    return $Primary + $Secondary
  }
}


class HostTools {
  static [int] GetHostHeight() {
    return (Get-Host).UI.RawUI.BufferSize.Height
  }
  static [int] GetHostWidth() {
    return ([type]'ConsoleWriter')::get_ConsoleWidth()
  }
  static [string] GetHostOs() {
    return [cryptobase]::GetHostOs()
  }
  static [object] InvokeInputBox([string]$Title, [string]$Prompt, [bool]$AsSecureString, [string]$BackgroundColor) {
    if ((Test-IsPSWindows)) {
      Add-Type -AssemblyName 'PresentationFramework'
      Add-Type -AssemblyName 'PresentationCore'
      Remove-Variable -Name myInput -Scope script -ErrorAction SilentlyContinue
      $form = New-Object System.Windows.Window
      $stack = New-Object System.Windows.Controls.StackPanel
      $form.Title = $Title
      $form.Height = 150
      $form.Width = 350
      $form.Background = $BackgroundColor
      $label = New-Object System.Windows.Controls.Label
      $label.Content = "    $Prompt"
      $label.HorizontalAlignment = "left"
      $stack.AddChild($label)
      if ($AsSecureString) {
        $inputbox = New-Object System.Windows.Controls.PasswordBox
      } else {
        $inputbox = New-Object System.Windows.Controls.TextBox
      }
      $inputbox.Width = 300
      $inputbox.HorizontalAlignment = "center"
      $stack.AddChild($inputbox)
      $space = New-Object System.Windows.Controls.Label
      $space.Height = 10
      $stack.AddChild($space)
      $btn = New-Object System.Windows.Controls.Button
      $btn.Content = "_OK"
      $btn.Width = 65
      $btn.HorizontalAlignment = "center"
      $btn.VerticalAlignment = "bottom"
      $btn.Add_click({
          if ($AsSecureString) { $script:myInput = $inputbox.SecurePassword } else { $script:myInput = $inputbox.text }
          $form.Close()
        })
      $stack.AddChild($btn)
      $space2 = New-Object System.Windows.Controls.Label
      $space2.Height = 10
      $stack.AddChild($space2)
      $btn2 = New-Object System.Windows.Controls.Button
      $btn2.Content = "_Cancel"
      $btn2.Width = 65
      $btn2.HorizontalAlignment = "center"
      $btn2.VerticalAlignment = "bottom"
      $btn2.Add_click({ $form.Close() })
      $stack.AddChild($btn2)
      $form.AddChild($stack)
      [void]$inputbox.Focus()
      $form.WindowStartupLocation = 1
      [void]$form.ShowDialog()
      return $script:myInput
    } else {
      Write-Warning "Sorry. This command requires a Windows platform."
      return $null
    }
  }
  static [object] InvokeInputBox() {
    return [HostTools]::InvokeInputBox("User Input", "Please enter a value:", $false, "White")
  }
}


class ModuleTools {
  static [hashtable] GetModuleData() {
    $d = @{}
    Get-ChildItem -Path "$((Get-Module cliHelper.core).ModuleBase)/en-US" -File data*.csv | ForEach-Object {
      $d[$_.Name.Replace('data.', '').Replace('.csv', '')] = [IO.File]::ReadAllText($_.FullName) | ConvertFrom-Csv
    }
    return $d
  }
}


class ProgressUtil {
  static [PsRecord] $data

  static ProgressUtil() {
    # Static constructor: build $data explicitly to avoid PsRecord's broken implicit
    # hashtable-cast (which fails on non-hashtable values like string arrays & scriptblocks).
    $d = [PsRecord]::new()
    $d.Add('ShowProgress', [scriptblock] { return (Get-Variable 'ProgressPreference' -ValueOnly) -eq 'Continue' })
    $d.Add('DefaultProgressMsg', 'Running background task')
    $d.Add('ProgressBarColor', 'LightSeaGreen')
    $d.Add('ProgressMsgColor', 'LightGoldenrodYellow')
    $d.Add('ProgressBlock', '■')
    $d.Add('TwirlFrames', '')
    $d.Add('TwirlEmojis', [string[]]@(
        '◰◳◲◱', '◇◈◆', '◐◓◑◒', '←↖↑↗→↘↓↙',
        '┤┘┴└├┌┬┐', '⣾⣽⣻⢿⡿⣟⣯⣷', '|/-\', '-\|/', '|/-\'
      )
    )
    [ProgressUtil]::data = $d
  }
  static [void] WriteProgressBar([int]$percent) {
    [ProgressUtil]::WriteProgressBar($percent, $true, "")
  }
  static [void] WriteProgressBar([int]$percent, [string]$message) {
    [ProgressUtil]::WriteProgressBar($percent, $true, $message)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [string]$message) {
    [ProgressUtil]::WriteProgressBar($percent, $update, [int]([ConsoleWriter]::get_ConsoleWidth() * 0.7), $message)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [string]$message, [bool]$Completed) {
    [ProgressUtil]::WriteProgressBar($percent, $update, [int]([ConsoleWriter]::get_ConsoleWidth() * 0.7), $message, $Completed)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [int]$PBLength, [string]$message) {
    [ProgressUtil]::WriteProgressBar($percent, $update, $PBLength, $message, $false)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [int]$PBLength, [string]$message, [bool]$Completed) {
    [ProgressUtil]::WriteProgressBar($percent, $update, $PBLength, $message, $Completed, [ProgressUtil]::data.ProgressBarcolor)
  }
  static [void] WriteProgressBar([int]$percent, [bool]$update, [int]$PBLength, [string]$message, [bool]$Completed, [string]$PBcolor) {
    <#
    .SYNOPSIS
      A simple progress utility class
    .EXAMPLE
      for ($i = 0; $i -le 100; $i++) { [ProgressUtil]::WriteProgressBar($i, "doing stuff") }
    #>
    if ([ProgressUtil]::data.ShowProgress) {
      [ValidateNotNull()][int]$PBLength = $PBLength; [ValidateNotNull()][int]$percent = $percent; $PmsgColor = [ProgressUtil]::data.ProgressMsgcolor
      [ValidateNotNull()][bool]$update = $update; [ValidateNotNull()][string]$message = $message;
      [ValidateScript( { return [bool][RGB]$_ })][string]$PmsgColor = $PmsgColor;
      [ValidateScript( { return [bool][RGB]$_ })][string]$PBcolor = $PBcolor;
      if ($update) { (Get-Host).UI.Write(("`b" * [ConsoleWriter]::get_ConsoleWidth())) }
      Write-Console $message -f $PmsgColor -NoNewLine
      Write-Console " [" -f $PBcolor -NoNewLine
      $p = [int](($percent / 100.0) * $PBLength + 0.5)
      for ($i = 0; $i -lt $PBLength; $i++) {
        if ($i -ge $p) {
          Write-Console ' ' -NoNewLine
        } else {
          Write-Console ([ProgressUtil]::data.ProgressBlock) -f $PBcolor -NoNewLine
        }
      }
      Write-Console "] " -f $PBcolor -NoNewLine
      Write-Console ("{0,3:##0}%" -f $percent) -f $PmsgColor -NoNewLine:(!$Completed)
    } else {
      Write-Debug '[ProgressUtil]::data.ShowProgress is set to false. Progress bar will not be displayed. Please enable it by running [ProgressUtil]::ToggleShowProgress()'
    }
  }
  static [Results] WaitJob([string]$progressMsg, [scriptblock]$sb) {
    return [ProgressUtil]::WaitJob($progressMsg, $sb, $null)
  }
  static [Results] WaitJob([string]$progressMsg, [System.Management.Automation.Job]$Job) {
    return [ProgressUtil]::WaitJob($progressMsg, $Job, [ProgressUtil]::data.ProgressMsgcolor)
  }
  static [Results] WaitJob([string]$progressMsg, [System.Management.Automation.Job]$Job, [string]$PmsgColor) {
    <#
    .DESCRIPTION
      Visual progress bar that spins while waiting for a job to complete.
      Uses cliHelper.core robust Progress framework preventing silent failures.
      Types are resolved at runtime to avoid PowerShell parse-time type resolution
      failures for transitively-imported module classes.
    #>
    [System.Diagnostics.Stopwatch]$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # --- Runtime type resolution (avoids parse-time [TypeName] failures for transitive using module deps) ---
    $consoleType = [type]'AnsiConsole'
    $progressType = [type]'Progress'
    $settingsType = [type]'ProgressTaskSettings'
    $descColType = [type]'TaskDescriptionColumn'
    $spinColType = [type]'SpinnerColumn'
    $colorType = [type]'Color'

    $console = $consoleType::Console
    $progress = $progressType::new($console)
    $progress.Columns.Clear()
    $progress.Columns.Add($descColType::new($progress))
    $progress.Columns.Add($spinColType::new($progress))

    # Translate legacy RGB color name to Spectre markup color string
    try {
      $colorObj = $colorType::FromName($PmsgColor)
      $PmsgColorStyle = if ($null -eq $colorObj -or $colorObj.IsDefault) { 'yellow' } else { $colorObj.ToMarkup() }
    } catch {
      $PmsgColorStyle = 'yellow'
    }

    # Capture outer variables for use inside the Action scriptblock.
    # NOTE: Progress.Start() is synchronous — the action runs on the MAIN thread.
    # To animate the spinner we must call a task-state method (SetValue/SetDescription)
    # each loop iteration so it fires TriggerUpdate() → OnUpdate → liveSession.Tick()
    # → SpinnerColumn advances a frame → console render. Without this, the main thread
    # just sleeps and the spinner never draws.
    $capturedJob = $Job
    $capturedMsg = $PmsgColorStyle
    $capturedMsgText = $progressMsg
    $capturedSettings = $settingsType::new()
    $capturedSettings.IsIndeterminate = $true   # keep task alive during SetValue(0) loop

    $progress.Start([System.Action[object]] {
        param([object]$ctx)
        $task = $ctx.AddTask("[$capturedMsg]$capturedMsgText[/]", $capturedSettings)
        while ($capturedJob.JobStateInfo.State -notin @('Completed', 'Failed', 'Stopped')) {
          [System.Threading.Thread]::Sleep(80)
          # Fire OnUpdate → Tick() → spinner frame advance + console render
          $task.SetValue(0)
        }
        $task.Complete()   # sets IsCompleted=$true, shows ✓ in SpinnerColumn
      }
    )

    $stopwatch.Stop()
    $elapsed = $stopwatch.Elapsed.TotalSeconds
    $res = [Results]::new()

    # Collect errors from child jobs
    [object[]]$Errors = @($Job.ChildJobs | Where-Object { $null -ne $_.Error } | ForEach-Object { $_.Error })

    # Pre-declare $errVars so it's always in scope regardless of -ErrorVariable behavior
    $errVars = [System.Collections.ArrayList]::new()
    $errVarsTmp = @()
    $jobOutputs = Receive-Job -Job $Job -ErrorAction SilentlyContinue -ErrorVariable errVarsTmp
    if ($errVarsTmp.Count -gt 0) {
      foreach ($e in $errVarsTmp) { [void]$errVars.Add($e) }
    }

    if ($Job.JobStateInfo.State -in @('Failed', 'Stopped') -or $Errors.Count -gt 0 -or $errVars.Count -gt 0) {
      if ($Errors.Count -gt 0) {
        $res.Add([Result]::Err($Errors[0]), $elapsed)
      } elseif ($errVars.Count -gt 0) {
        $res.Add([Result]::Err($errVars[0]), $elapsed)
      } else {
        $res.Add([Result]::Err([System.Exception]::new('Job failed without a specific error.')), $elapsed)
      }
    } else {
      $res.Add([Result]::Ok($jobOutputs), $elapsed)
    }

    return $res
  }
  static [Results] WaitJob([string]$progressMsg, [scriptblock]$sb, [Object[]]$ArgumentList) {
    if ($null -ne $ArgumentList) {
      $Job = Start-ThreadJob -ScriptBlock $sb -ArgumentList $ArgumentList
    } else {
      $Job = Start-ThreadJob -ScriptBlock $sb
    }
    return [ProgressUtil]::WaitJob($progressMsg, $Job)
  }
  static [void] ToggleShowProgress() {
    # .DESCRIPTION
    # The ShowProgress option respects $ProgressPreference, this method enables you to take control of that and set/toggle it manualy.
    [ProgressUtil]::data.Set('ShowProgress', [scriptblock]::Create(" return [bool]$([int]![ProgressUtil]::data.ShowProgress)"))
  }
}

class StringTools {
  static [string[]] SplitLine([string]$String) {
    if ($String -notmatch "`n") { return , ([array]$String) }
    $ReturnValue = $String -split "`r`n"
    if ($ReturnValue.Count -eq 1) { $ReturnValue = $String -split "`n" }
    return $ReturnValue
  }
  static [Object[]] SplitStringOnLiteralString([string]$objToSplit, [string]$objSplitter) {
    if ([string]::IsNullOrEmpty($objToSplit)) { return @() }
    if ([string]::IsNullOrEmpty($objSplitter)) { return @($objToSplit) }
    $objSplitterInRegEx = [regex]::Escape($objSplitter)
    $result = @([regex]::Split($objToSplit, $objSplitterInRegEx))
    return $result
  }
  static [string] ReverseString([string]$Inputstr) {
    if ([string]::IsNullOrEmpty($Inputstr)) { return $Inputstr }
    $charArray = $Inputstr.ToCharArray()
    [Array]::Reverse($charArray)
    return [string]::new($charArray)
  }
  static [string] ToTitleCase([string]$Inputstr) {
    if ([string]::IsNullOrEmpty($Inputstr)) { return $Inputstr }
    $TextInfo = (Get-Culture).TextInfo
    return $TextInfo.ToTitleCase($Inputstr.ToLower())
  }
}


