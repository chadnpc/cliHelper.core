
using module .\Console\Colors.psm1
using module .\Models.psm1
using module .\Console.psm1
using module .\Console\Internal.psm1

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
  static [PsRecord] $data = @{
    ShowProgress     = { return (Get-Variable 'VerbosePreference' -ValueOnly) -eq 'Continue' }
    ProgressBarColor = "LightSeaGreen"
    ProgressMsgColor = "LightGoldenrodYellow"
    ProgressBlock    = '■'
    TwirlFrames      = ''
    TwirlEmojis      = [string[]]@(
      "◰◳◲◱",
      "◇◈◆",
      "◐◓◑◒",
      "←↖↑↗→↘↓↙",
      "┤┘┴└├┌┬┐",
      "⣾⣽⣻⢿⡿⣟⣯⣷",
      "|/-\\",
      "-\\|/",
      "|/-\\"
    )
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
  static [System.Management.Automation.Job] WaitJob([string]$progressMsg, [scriptblock]$sb) {
    return [ProgressUtil]::WaitJob($progressMsg, $sb, $null)
  }
  static [System.Management.Automation.Job] WaitJob([string]$progressMsg, [System.Management.Automation.Job]$Job) {
    return [ProgressUtil]::WaitJob($progressMsg, $Job, [ProgressUtil]::data.ProgressMsgcolor)
  }
  static [System.Management.Automation.Job] WaitJob([string]$progressMsg, [System.Management.Automation.Job]$Job, [string]$PmsgColor) {
    <#
    .DESCRIPTION
      waitjob is different from writeprogressbar - it's a visual progress bar that spins while waiting for a job to complete
      useful when we don't know the percentage of completion or it's not linear.
      we use it to create a better visual experience when waiting for long running operations.
    .EXAMPLE
      [ProgressUtil]::WaitJob("waiting", { Start-Sleep -Seconds 3 });
    .EXAMPLE
      $j = [ProgressUtil]::WaitJob("Waiting", { Param($ob) Start-Sleep -Seconds 3; return $ob }, (Get-Process pwsh));
      $j | Receive-Job

      NPM(K)    PM(M)      WS(M)     CPU(s)      Id  SI ProcessName
      ------    -----      -----     ------      --  --
            0     0.00     559.55      94.22   53184 …84 pwsh
            0     0.00     253.84       6.91   55195 …23 pwsh
    .EXAMPLE
      Wait-Task -ScriptBlock { Start-Sleep -Seconds 3; $input | Out-String } -InputObject (Get-Process pwsh)
    .EXAMPLE
      $RequestParams = @{
        Uri    = 'https://jsonplaceholder.typicode.com/todos/1'
        Method = 'GET'
      }
      $result = [ProgressUtil]::WaitJob("Making a request", { Param($rp) Start-Sleep -Seconds 2; Invoke-RestMethod @rp }, $RequestParams) | Receive-Job
      echo $result

      userId id title              completed
      ------ -- -----              ---------
          1  1 delectus aut autem     False
    #>
    [Console]::CursorVisible = $false; [ValidateScript( { return [bool][RGB]$_ })][string]$PmsgColor = $PmsgColor
    [ProgressUtil]::data.TwirlFrames = [ProgressUtil]::data.TwirlEmojis[8]; $PBcolor = [ProgressUtil]::data.ProgressBarcolor
    [ValidateScript( { return [bool][RGB]$_ })][string]$PBcolor = $PBcolor
    [int]$length = [ProgressUtil]::data.TwirlFrames.Length;
    $originalY = [Console]::CursorTop
    while ($Job.JobStateInfo.State -notin ('Completed', 'failed')) {
      for ($i = 0; $i -lt $length; $i++) {
        [ProgressUtil]::data.TwirlFrames.Foreach({
            Write-Console "$progressMsg" -NoNewLine -f $PmsgColor
            Write-Console " $($_[$i])" -NoNewLine -f $PBcolor
          })
        [System.Threading.Thread]::Sleep(50)
        Write-Console ("`b" * ($length + $progressMsg.Length)) -NoNewLine -f $PmsgColor
        [Console]::CursorTop = $originalY
      }
    }
    Write-Console "`b$progressMsg ... " -NoNewLine -f $PmsgColor
    [System.Management.Automation.Runspaces.RemotingErrorRecord[]]$Errors = $Job.ChildJobs.Where({
        $null -ne $_.Error
      }
    ).Error;
    if ($Job.JobStateInfo.State -eq "Failed" -or $Errors.Count -gt 0) {
      $errormessages = [string]::Empty
      if ($null -ne $Errors) {
        $errormessages = $Errors.Exception.Message -join "`n"
      }
      Write-Console "Completed with errors.`n`t$errormessages" -f Salmon
    } else {
      Write-Console "Done" -f Green
    }
    [Console]::CursorVisible = $true;
    return $Job
  }
  static [System.Management.Automation.Job] WaitJob([string]$progressMsg, [scriptblock]$sb, [Object[]]$ArgumentList) {
    $Job = ($null -ne $ArgumentList) ? (Start-ThreadJob -ScriptBlock $sb -ArgumentList $ArgumentList ) : (Start-ThreadJob -ScriptBlock $sb)
    return [ProgressUtil]::WaitJob($progressMsg, $Job)
  }
  static [void] ToggleShowProgress() {
    # .DESCRIPTION
    # The ShowProgress option respects $verbosepreference, this method enables you to take control of that and set/toggle it manualy.
    [ProgressUtil]::data.Set("ShowProgress", [scriptblock]::Create(" return [bool]$([int]![ProgressUtil]::data.ShowProgress)"))
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


