using namespace System.IO
using namespace System.Text
using namespace System.Collections.Generic
using namespace System.Collections.Specialized
using namespace System.Management.Automation

using module .\Enums.psm1
using module .\Exceptions.psm1
using module .\Console\Colors.psm1
using module .\FontMan.psm1
using module .\MotdGen.psm1
using module .\Utilities.psm1

class InstallRequirements {
  [Requirement[]] $list = @()
  [bool] $resolved = $false
  [string] $jsonPath = [IO.Path]::Combine($(Resolve-Path .).Path, 'requirements.json')

  InstallRequirements() {}
  InstallRequirements([array]$list) { $this.list = $list }
  InstallRequirements([List[array]]$list) { $this.list = $list.ToArray() }
  InstallRequirements([Hashtable]$Map) { $Map.Keys | ForEach-Object { $Map[$_] ? ($this.$_ = $Map[$_]) : $null } }
  InstallRequirements([Requirement]$req) { $this.list += $req }
  InstallRequirements([Requirement[]]$list) { $this.list += $list }

  [void] Resolve() {
    $this.Resolve($false, $false)
  }
  [void] Resolve([switch]$Force, [switch]$What_If) {
    $res = $true; $this.list.ForEach({ $res = $res -and $_.Resolve($Force, $What_If) })
    $this.resolved = $res
  }
  [void] Import() {
    $this.Import($this.JsonPath, $false)
  }
  [void] Import([switch]$throwOnFail) {
    $this.Import($this.JsonPath, $throwOnFail)
  }
  [void] Import([string]$JsonPath, [switch]$throwOnFail) {
    if ([IO.File]::Exists($JsonPath)) { $this.list = Get-Content $JsonPath | ConvertFrom-Json }; return
    if ($throwOnFail) {
      throw [FileNotFoundException]::new("Requirement json file not found: $JsonPath")
    }
  }
  [void] Export() {
    $this.Export($this.JsonPath)
  }
  [void] Export([string]$JsonPath) {
    $this.list | ConvertTo-Json -Depth 1 -Verbose:$false | Out-File $JsonPath
  }
  [string] ToString() {
    return $this | ConvertTo-Json
  }
}

class Requirement {
  [string] $Name
  [version] $Version
  [string] $Description
  [string] $InstallScript
  hidden [PSDataCollection[PsObject]]$Output

  Requirement() {}
  Requirement([array]$arr) {
    $this.Name = $arr[0]
    $this.Version = $arr.Where({ $_ -is [version] })[0]
    $this.Description = $arr.Where({ $_ -is [string] -and $_ -ne $this.Name })[0]
    $__sc = $arr.Where({ $_ -is [scriptblock] })[0]
    $this.InstallScript = ($null -ne $__sc) ? $__sc.ToString() : $arr[-1]
  }
  Requirement([string]$Name, [scriptblock]$InstallScript) {
    $this.Name = $Name
    $this.InstallScript = $InstallScript.ToString()
  }
  Requirement([string]$Name, [string]$Description, [scriptblock]$InstallScript) {
    $this.Name = $Name
    $this.Description = $Description
    $this.InstallScript = $InstallScript.ToString()
  }

  [bool] IsInstalled() {
    try {
      Get-Command $this.Name -Type Application
      return $?
    } catch [CommandNotFoundException] {
      return $false
    } catch {
      throw [InstallException]::new("Failed to check if $($this.Name) is installed", $_.Exception)
    }
  }
  [bool] Resolve() {
    return $this.Resolve($false, $false)
  }
  [bool] Resolve([switch]$Force, [switch]$What_If) {
    $is_resolved = $true; $this.Output = [PSDataCollection[PsObject]]::new()
    $v = [ProgressUtil]::data.ShowProgress
    if (!$this.IsInstalled() -or $Force.IsPresent) {
      $v ? (Write-Console "`n[Resolve requrement] $($this.Name) " -f DarkKhaki -NoNewLine) : $null
      if ([string]::IsNullOrWhiteSpace($this.Description)) {
        $v ? (Write-Console "($($this.Description)) " -f Wheat -NoNewLine) : $null
      }
      $v ? (Write-Console "$($this.Version) " -f Green) : $null
      if ($What_If.IsPresent) {
        $v ? (Write-Console "Would install: $($this.Name)" -f Yellow) : $null
      } else {
        $this.Output += $this.InstallScript | Invoke-Expression
      }
      $is_resolved = $?
    }
    return $is_resolved
  }
}

class ProfileConfig : PsRecord {
  [string]$Title = 'Terminal'
  [Encoding]$Encoding = 'UTF8' # Default is utf-8 Encoding
  [bool]$AutoLogon #Specifies credentials for an account that is used to automatically log on to the computer.
  [bool]$BluetoothTaskbarIconEnabled #Specifies whether to enable the Bluetooth taskbar icon.
  [string]$ComputerName #Specifies the name of the computer.
  [bool]$ConvertibleSlateModePromptPreference # Configure to support prompts triggered by changes to ConvertibleSlateMode. OEMs must make sure that ConvertibleSlateMode is always accurate for their devices.
  [string]$path = [IO.Path]::Combine([Environment]::GetFolderPath('MyDocuments'), 'WindowsPowershell', 'Microsoft.PowerShell_profile.ps1')
  [bool]$AutoUpdate = $true
  [bool]$AutoLoad = $true
  [Microsoft.PowerShell.ExecutionPolicy]$ExecutionPolicy = "RemoteSigned"
  [bool]$CopyProfile = $true
  [bool]$DisableAutoDaylightTimeSet #Specifies whether to enable the destination computer to automatically change between daylight saving time and standard time.
  [array]$Display # Specifies display settings to apply to a destination computer.
  [string[]]$FirstLogonCommands #Specifies commands to run the first time that an end user logs on to the computer. This setting is not supported in Windows 10 in S mode.
  [string[]]$FolderLocations #Specifies the location of the user profile and program data folders.
  [string[]]$LogonCommands #Specifies commands to run when an end user logs on to the computer.
  [array]$NotificationArea #Specifies settings that are related to the system notification area at the far right of the taskbar.
  [string]$SignInMode #Specifies whether users switch to tablet mode by default after signing in.
  [string[]]$TaskbarLinks #Specifies shortcuts to display on the taskbar. You can specify up to three links.
  [string[]]$Themes #Specifies custom elements of the Windows visual style.
  [TimeZone]$TimeZone = [TimeZone]::CurrentTimeZone #Specifies the computer's time zone.
  [string[]]$VisualEffects #Specifies additional display settings.
  [string[]]$WindowsFeatures
  [InstallRequirements]$RequiredModules = @(
    ("pipenv", "Python virtualenv management tool", { Install-PipEnv } ),
    ("oh-my-posh", "A cross platform tool to render your prompt.", { Install-OMP } ),
    ("PSReadLine", "Provides gread command line editing in the PowerShell console host", { Install-Module PSReadLine } ),
    ("posh-git", "Provides prompt with Git status summary information and tab completion for Git commands, parameters, remotes and branch names.", { Install-Module posh-git } ),
    ("PowerType", "A module providing recommendations for common tools. For more information : https://github.com/AnderssonPeter/PowerType", { Install-Module PowerType } ),
    ("PSFzf", "A wrapper module around Fzf (https://github.com/junegunn/fzf).", { Install-Module PSFzf } ),
    ("Terminal-Icons", "A module to add file icons to terminal based on file extensions", { Install-Module Terminal-Icons } )
  )
  [string]$OmpConfig #Path to omp.json

  ProfileConfig() {}

  [xml] ToXML() {
    return $this.PsObject.Properties | Export-Clixml
  }
  [string] ToJSON() {
    return $this.PsObject.Properties | Select-Object Name, value | ConvertTo-Json
  }
  [string] ToString() {
    return [string]::Empty
  }
}


class PsProfile : PsRecord {
  [HostOs] $HostOS
  [PsObject] $PROFILE
  [string[]] $ompJson
  [char] $swiglyChar
  [Hashtable] $colors
  [PsObject] $PSVersn
  [bool] $CurrExitCode
  [char] $DirSeparator
  [string] $Home_Indic
  [string] $WindowTitle
  [string] $leadingChar
  [string] $trailngChar
  [IO.FileInfo] $LogFile
  [IO.FileInfo] $OmpJsonFile
  [string] $Default_Term_Ascii
  [string[]] $Default_Dependencies
  [string] $WINDOWS_TERMINAL_JSON_PATH
  [Int32] $realLASTEXITCODE = $LASTEXITCODE
  [PSCustomObject] $TERMINAL_Settings

  # brackets, dots, newline
  hidden [string] $b1
  hidden [string] $b2
  hidden [string] $dt
  hidden [string] $nl

  PsProfile () {
    $this.Set_Defaults()
  }
  [void] Initialize() {
    $this.Initialize(@())
  }
  [void] Initialize([string[]]$DependencyModules) {
    $this.Initialize(@(), $false)
  }
  [void] Initialize([string[]]$DependencyModules, [bool]$force) {
    $v = [ProgressUtil]::data.ShowProgress
    $v ? (Write-Console '[PsProfile] Set variable defaults' -f DarkKhaki) : $null
    $this.Set_Defaults()
    $v ? (Write-Console '[PsProfile] Resolving Requirements ... (a one-time process)' -f DarkKhaki) : $null
    # Inspired by: https://dev.to/ansonh/customize-beautify-your-windows-terminal-2022-edition-541l
    if ($null -eq (Get-PSRepository -Name PSGallery -ErrorAction Ignore)) {
      throw 'PSRepository named PSGallery was Not found!'
    }
    Set-PSRepository PSGallery -InstallationPolicy Trusted;
    $PackageProviderNames = (Get-PackageProvider -ListAvailable).Name
    $requiredModules = $this.Default_Dependencies + $DependencyModules | Sort-Object -Unique
    foreach ($name in @("NuGet", "PowerShellGet")) {
      if ($force) {
        Install-PackageProvider $name -Force
      } elseif ($PackageProviderNames -notcontains $name) {
        Install-PackageProvider $name -Force
      } else {
        $v ? (Write-Console "PackageProvider '$name' is already Installed." -f Wheat) : $null
      }
    }
    # Install requied modules: # we could use Install-Module -Name $_ but it fails sometimes
    $requiredModules | Resolve-Module
    # BeautifyTerminal :
    if ($this.IsTerminalInstalled()) {
      $this.AddColorScheme()
    } else {
      Write-Warning "Windows terminal is not Installed!"
    }
    $this.InstallNerdFont()
    $this.InstallOhMyPosh() # instead of: winget install JanDeDobbeleer.OhMyPosh
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView # Optional
    # WinFetch
    Install-Script -Name winfetch -AcceptLicense

    if (!(Test-Path -Path $env:USERPROFILE/.config/winfetch/config.ps1)) {
      winfetch -genconf
    }
    (Get-Content $env:USERPROFILE/.config/winfetch/config.ps1).Replace('# $ShowDisks = @("*")', '$ShowDisks = @("*")') | Set-Content $env:USERPROFILE/.config/winfetch/config.ps1
    (Get-Content $env:USERPROFILE/.config/winfetch/config.ps1).Replace('# $memorystyle', '$memorystyle') | Set-Content $env:USERPROFILE/.config/winfetch/config.ps1
    (Get-Content $env:USERPROFILE/.config/winfetch/config.ps1).Replace('# $diskstyle', '$diskstyle') | Set-Content $env:USERPROFILE/.config/winfetch/config.ps1
    # RESET current exit code:
    $this.CurrExitCode = $true

    $v ? (Write-Console '[PsProfile] Load configuration settings ...' -f DarkKhaki) : $null
    $this.LoadConfiguration()

    Set-Variable -Name Colors -Value $($this.colors) -Scope Global -Visibility Public -Option AllScope
    if ($force) {
      # Invoke-Command -ScriptBlock $Load_Profile_Functions
      $this.CurrExitCode = $? -and $($this.Create_Prompt_Function())
    } else {
      if (!$($this.IsInitialised())) {
        # Invoke-Command -ScriptBlock $Load_Profile_Functions
        $this.CurrExitCode = $? -and $($this.Create_Prompt_Function())
      } else {
        $v ? (Write-Console "[PsProfile] is already Initialized, Skipping ..." -f Wheat) : $null
      }
    }
    [void]$this.GetPsProfile() # create the $profile file if it does not exist
    $this.Set_TerminalUI()
    $v ? (Write-Console "[PsProfile] Displaying a welcome message/MOTD ..." -f DarkKhaki) : $null
    $this.Write_Term_Ascii()
  }
  [bool] IsInitialised() {
    return (Get-Variable -Name IsPromptInitialised -Scope Global).Value
  }
  [void] LoadConfiguration() {
    $this.TERMINAL_Settings = $this.GetTerminalSettings();
  }
  [PSCustomObject] GetTerminalSettings() {
    if ($this.IsTerminalInstalled()) {
      if ([IO.Directory]::Exists($this.WINDOWS_TERMINAL_JSON_PATH)) {
        return (Get-Content $($this.WINDOWS_TERMINAL_JSON_PATH) -Raw | ConvertFrom-Json)
      }
      Write-Warning "Could not find WINDOWS_TERMINAL_JSON_PATH!"
    } else {
      Write-Warning "Windows terminal is not installed!"
    }
    return $null
  }
  [void] SaveTerminalSettings([PSCustomObject]$settings) {
    # Save changes (Write Windows Terminal settings)
    $settings | ConvertTo-Json -Depth 32 | Set-Content $($this.WINDOWS_TERMINAL_JSON_PATH)
  }
  hidden [void] AddColorScheme() {
    $settings = $this.GetTerminalSettings();
    if ($null -ne $settings) {
      $sonokaiSchema = [PSCustomObject]@{
        name                = "Sonokai Shusia"
        background          = "#2D2A2E"
        black               = "#1A181A"
        blue                = "#1080D0"
        brightBlack         = "#707070"
        brightBlue          = "#22D5FF"
        brightCyan          = "#7ACCD7"
        brightGreen         = "#A4CD7C"
        brightPurple        = "#AB9DF2"
        brightRed           = "#F882A5"
        brightWhite         = "#E3E1E4"
        brightYellow        = "#E5D37E"
        cursorColor         = "#FFFFFF"
        cyan                = "#3AA5D0"
        foreground          = "#E3E1E4"
        green               = "#7FCD2B"
        purple              = "#7C63F2"
        red                 = "#F82F66"
        selectionBackground = "#FFFFFF"
        white               = "#E3E1E4"
        yellow              = "#E5DE2D"
      }
      # Check color schema added before or not?
      if ($settings.schemes | Where-Object -Property name -EQ $sonokaiSchema.name) {
        Write-Host "[PsProfile] Terminal Color Theme was added before"
      } else {
        $settings.schemes += $sonokaiSchema
        # Check default profile has colorScheme or not
        if ($settings.profiles.defaults | Get-Member -Name 'colorScheme' -MemberType Properties) {
          $settings.profiles.defaults.colorScheme = $sonokaiSchema.name
        } else {
          $settings.profiles.defaults | Add-Member -MemberType NoteProperty -Name 'colorScheme' -Value $sonokaiSchema.name
        }
        $this.SaveTerminalSettings($settings);
      }
    } else {
      Write-Warning "[PsProfile] Could not get TerminalSettings, please make sure windowsTerminal is installed."
    }
  }
  hidden [void] InstallNerdFont() {
    $this.InstallNerdFont('FiraCode')
  }
  hidden [void] InstallNerdFont([string]$FontName) {
    #Requires -Version 3.0
    [ValidateNotNullorEmpty()][string]$FontName = $FontName
    $v = [ProgressUtil]::data.ShowProgress
    if ([FontMan]::GetInstalledFonts().Contains("$FontName")) {
      $v ? (Write-Console "[PsProfile] Font '$FontName' is already installed!" -f Wheat) : $null
      return
    }
    $v ? (Write-Console "Install required Font:  ($FontName)" -f Magenta) : $null
    [IO.DirectoryInfo]$FiraCodeExpand = [IO.Path]::Combine($env:temp, 'FiraCodeExpand')
    if (![System.IO.Directory]::Exists($FiraCodeExpand.FullName)) {
      $fczip = [IO.FileInfo][IO.Path]::Combine($env:temp, 'FiraCode.zip')
      if (![IO.File]::Exists($fczip.FullName)) {
        Invoke-WebRequest -Uri https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip -OutFile $fczip.FullName
      }
      Expand-Archive -Path $fczip.FullName -DestinationPath $FiraCodeExpand.FullName
      Remove-Item -Path $fczip.FullName -Recurse
    }
    # Install Fonts
    # the Install-Font function is found in PSWinGlue module
    "PSWinGlue" | Resolve-Module
    Import-Module -Name PSWinGlue -WarningAction silentlyContinue
    # Elevate to Administrative
    if (!$this.IsAdministrator()) {
      $command = "Install-Font -Path '{0}'" -f ([IO.Path]::Combine($env:temp, 'FiraCodeExpand'))
      Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command {$command}" -Verb RunAs -Wait -WindowStyle Minimized
    }
    $settings = $this.GetTerminalSettings()
    if ($null -ne $settings) {
      # Check default profile has font or not
      if ($settings.profiles.defaults | Get-Member -Name 'font' -MemberType Properties) {
        $settings.profiles.defaults.font.face = 'FiraCode Nerd Font'
      } else {
        $settings.profiles.defaults | Add-Member -MemberType NoteProperty -Name 'font' -Value $(
          [PSCustomObject]@{
            face = 'FiraCode Nerd Font'
          }
        ) | ConvertTo-Json
      }
      $this.SaveTerminalSettings($settings);
    } else {
      Write-Warning "Could update Terminal font settings!"
    }
  }
  hidden [void] InstallWinget() {
    Write-Host "Install winget" -ForegroundColor Magenta
    $wngt = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
    $deps = ('Microsoft.VCLibs.x64.14.00.Desktop.appx', 'Microsoft.UI.Xaml.x64.appx')
    $PPref = Get-Variable -Name progressPreference -Scope Global; $progressPreference = 'silentlyContinue'
    $IPref = Get-Variable -Name InformationPreference -Scope Global; $InformationPreference = "Continue"
    if ([bool](Get-Command winget -Type Application -ea Ignore) -and !$PSBoundParameters.ContainsKey('Force')) {
      Write-Host "Winget is already Installed." -ForegroundColor Green -NoNewline; Write-Host " Use -Force switch to Overide it."
      return
    }
    # Prevent Error code: 0x80131539
    # https://github.com/PowerShell/PowerShell/issues/13138
    Get-Command Add-AppxPackage -ErrorAction Ignore
    if ($Error[0]) {
      if ($Error[0].GetType().FullName -in ('System.Management.Automation.CmdletInvocationException', 'System.Management.Automation.CommandNotFoundException')) {
        Write-Host "Module Appx is not loaded by PowerShell Core! Importing ..." -ForegroundColor Yellow
        Import-Module -Name Appx -UseWindowsPowerShell -Verbose:$false -WarningAction SilentlyContinue
      }
    }
    Write-Host "[0/3] Downloading WinGet and its dependencies ..." -ForegroundColor Green
    Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile $wngt
    Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile $deps[0]
    Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.7.3/Microsoft.UI.Xaml.2.7.x64.appx -OutFile $deps[1];

    Write-Host "[1/3] Installing $($deps[0]) ..." -ForegroundColor Green
    Add-AppxPackage -Path $deps[0]

    Write-Host "[2/3] Installing $($deps[1]) ..." -ForegroundColor Green
    Add-AppxPackage -Path $deps[1]

    Write-Host "[3/3] Installing $wngt ..." -ForegroundColor Green
    Add-AppxPackage -Path $wngt
    # cleanup
    $deps + $wngt | ForEach-Object { Remove-Item ($_ -as 'IO.FileInfo').FullName -Force -ErrorAction Ignore }
    # restore
    $progressPreference = $PPref
    $InformationPreference = $IPref
  }
  [void] InstallOhMyPosh() {
    $this.InstallOhMyPosh($true, $false)
  }
  [void] InstallOhMyPosh([bool]$AllUsers, [bool]$force) {
    $ompath = Get-Variable OH_MY_POSH_PATH -Scope Global -ValueOnly -ErrorAction Ignore
    if ($null -eq $ompath) { $this.Set_Defaults() }; $v = [ProgressUtil]::data.ShowProgress
    $ompdir = [IO.DirectoryInfo]::new((Get-Variable OH_MY_POSH_PATH -Scope Global -ValueOnly))
    if (!$ompdir.Exists) { [void]$this.Create_Directory($ompdir.FullName) }
    if (!$force -and [bool](Get-Command oh-my-posh -Type Application -ErrorAction Ignore)) {
      $v ? (Write-Console "oh-my-posh is already Installed; moing on ..." -f Wheat) : $null
      return
    }
    # begin installation
    $v ? (Write-Console "Install OhMyPosh" -f Magenta) : $null
    $installer = ''; $installInstructions = "`nHey friend`n`nThis installer is only available for Windows.`nIf you're looking for installation instructions for your operating system,`nplease visit the following link:`n"
    $Host_OS = $this.HostOS.ToString()
    if ($Host_OS -eq "MacOS") {
      $v ? (Write-Console "`n$installInstructions`n`nhttps://ohmyposh.dev/docs/installation/macos`n" -f Wheat) : $null
    } elseif ($Host_OS -eq "Linux") {
      $v ? (Write-Console "`n$installInstructions`n`nhttps://ohmyposh.dev/docs/installation/linux" -f Wheat) : $null
    } elseif ($Host_OS -eq "Windows") {
      $arch = (Get-CimInstance -Class Win32_Processor -Property Architecture).Architecture | Select-Object -First 1
      switch ($arch) {
        0 { $installer = "install-386.exe" }
        5 { $installer = "install-arm64.exe" }
        9 {
          if ([Environment]::Is64BitOperatingSystem) {
            $installer = "install-amd64.exe"
          } else {
            $installer = "install-386.exe"
          }
        }
        12 { $installer = "install-arm64.exe" }
      }
      if ([string]::IsNullOrEmpty($installer)) {
        throw "`nThe installer for system architecture ($(@{
                    0  = 'X86'
                    5  = 'ARM'
                    9  = 'AMD64/32'
                    12 = 'Surface'
                }.$arch)) is not available.`n"
      }
      $v ? (Write-Console "Downloading $installer..." -f DarkKhaki) : $null
      $omp_installer = [IO.FileInfo]::new("aux"); $ret_count = 0
      do {
        $omp_installer = [IO.FileInfo]::new([IO.Path]::Combine($env:TEMP, ([System.IO.Path]::GetRandomFileName() -replace '\.\w+$', '.exe'))); $ret_count++
      } while (![IO.File]::Exists($omp_installer.FullName) -and $ret_count -le 10)
      $url = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/$installer"
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
      Invoke-WebRequest -OutFile $omp_installer.FullName -Uri $url
      $v ? (Write-Console 'Running installer...' -f DarkKhaki) : $null
      $installMode = "/CURRENTUSER"
      if ($AllUsers) {
        $installMode = "/ALLUSERS"
      }

      & "$omp_installer" /VERYSILENT $installMode | Out-Null
      $omp_installer | Remove-Item
      #todo: refresh the shell
    } else {
      throw "Error: Could not determine the Host operating system."
    }
  }
  [bool] IsTerminalInstalled() {
    $IsInstalled = $true
    # check in wt if added to %PATH%
    $defWtpath = (Get-Command wt.exe -Type Application -ErrorAction Ignore).Source
    if (![string]::IsNullOrWhiteSpace($defWtpath)) {
      return $IsInstalled
    }
    # check generic paths: https://stackoverflow.com/questions/62894666/path-and-name-of-exe-file-of-windows-terminal-preview
    $genericwt = [IO.FileInfo]::new("$env:LocalAppData/Microsoft/WindowsApps/wt.exe")
    $msstorewt = [IO.FileInfo]::new("$env:LocalAppData/Microsoft/WindowsApps/Microsoft.WindowsTerminal_8wekyb3d8bbwe/wt.exe")
    $IsInstalled = $IsInstalled -and ($genericwt.Exists -or $msstorewt.Exists)
    return $IsInstalled
  }
  [bool] IsAdministrator() {
    return [bool]([Security.Principal.WindowsIdentity]::GetCurrent().Groups -match 'S-1-5-32-544')
  }
  [IO.FileInfo] GetPsProfile() {
    # This method will return the profile file (CurrentUserCurrentHost) and creates a new one if it does not already exist.
    $Documents_Path = $this.GetDocumentsPath()
    if (!$Documents_Path.Exists) {
      New-Item -Path $Documents_Path -ItemType Directory
    }
    # Manually get CurrentUserCurrentHost profile file
    $prof = [IO.FileInfo]::new([IO.Path]::Combine($Documents_Path, 'PowerShell', 'Microsoft.PowerShell_profile.ps1'))
    if (!$prof.Exists) { $prof = $this.GetPsProfile($prof) }
    return $prof
  }
  [IO.FileInfo] GetPsProfile([IO.FileInfo]$file) {
    if (!$file.Directory.Exists) { [void]$this.Create_Directory($file.Directory.FullName) }
    $file = New-Item -ItemType File -Path $file.FullName
    $this.Add_OMP_To_Profile($file)
    return $file
  }
  [IO.DirectoryInfo] GetDocumentsPath() {
    $User_docs_Path = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments)
    $Documents_Path = if (![IO.Path]::Exists($User_docs_Path)) {
      $UsrProfile = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
      $mydocsPath = if (![IO.Path]::Exists($UsrProfile)) {
        $commondocs = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::CommonDocuments)
        if (![IO.Path]::Exists($commondocs)) {
          $all_spec_docs_paths = (0..61 | ForEach-Object { (New-Object –COM "Shell.Application").NameSpace($_).Self.Path }).Where({ $_ -like "*$([IO.Path]::DirectorySeparatorChar)Documents" }).Foreach({ $_ })
          if ($all_spec_docs_paths.count -eq 0) {
            throw [System.InvalidOperationException]::new("Could not find Documents Path")
          }
          $all_spec_docs_paths[0]
        }
        $commondocs
      } else {
        [IO.Path]::Combine($UsrProfile, 'Documents')
      }
      $mydocsPath
    } else {
      $User_docs_Path
    }
    return $Documents_Path -as [IO.DirectoryInfo]
  }
  [string] Get_omp_Json() {
    if ([string]::IsNullOrWhiteSpace("$([string]$this.ompJson) ".Trim())) {
      return $this.get_omp_Json('omp.json', [uri]::new('https://gist.github.com/chadnpc/b106f0e618bb9bbef86611824fc37825'))
    }
    return $this.ompJson
  }
  [string] Get_omp_Json([string]$fileName, [uri]$gisturi) {
    Write-Host "Fetching the latest $fileName" -ForegroundColor Green;
    $gistId = $gisturi.Segments[-1];
    $jsoncontent = Invoke-WebRequest "https://gist.githubusercontent.com/chadnpc/$gistId/raw/$fileName" -Verbose:$false | Select-Object -ExpandProperty Content
    if ([string]::IsNullOrWhiteSpace("$jsoncontent ".Trim())) {
      throw [System.IO.InvalidDataException]::NEW('FAILED to get valid json string gtom github gist')
    }
    return $jsoncontent
  }
  [void] Set_omp_Json() {
    $this.set_omp_Json('omp.json', [uri]::new('https://gist.github.com/chadnpc/b106f0e618bb9bbef86611824fc37825'))
  }
  [void] Set_omp_Json([string]$fileName, [uri]$gisturi) {
    if ($null -eq $this.OmpJsonFile.FullName) { $this.Set_Defaults() }
    $this.OmpJsonFile = [IO.FileInfo]::New([IO.Path]::Combine($(Get-Variable OH_MY_POSH_PATH -Scope Global -ValueOnly -ErrorAction Ignore), 'themes', 'p10k_classic.omp.json'))
    if (!$this.OmpJsonFile.Exists) {
      if (!$this.OmpJsonFile.Directory.Exists) { [void]$this.Create_Directory($this.OmpJsonFile.Directory.FullName) }
      $this.OmpJsonFile = New-Item -ItemType File -Path ([IO.Path]::Combine($this.OmpJsonFile.Directory.FullName, $this.OmpJsonFile.Name))
      $this.get_omp_Json($fileName, $gisturi) | Out-File ($this.OmpJsonFile.FullName) -Encoding utf8
    } else {
      Write-Host "Found $($this.OmpJsonFile)" -ForegroundColor Green
    }
    $this.ompJson = [IO.File]::ReadAllLines($this.OmpJsonFile.FullName)
  }
  [void] Set_Defaults() {
    Write-Verbose "Set defaults ..."
    $this.Default_Dependencies = @('Terminal-Icons', 'PSReadline', 'Pester', 'Posh-git', 'PSWinGlue', 'PowerShellForGitHub');
    $this.swiglyChar = [char]126;
    $this.DirSeparator = [System.IO.Path]::DirectorySeparatorChar;
    $this.nl = [Environment]::NewLine;
    # UTF8 Characters from https://www.w3schools.com/charsets/ref_utf_box.asp
    $this.dt = [string][char]8230;
    $this.b1 = [string][char]91;
    $this.b2 = [string][char]93;
    $this.Home_Indic = $this.swiglyChar + [IO.Path]::DirectorySeparatorChar;
    $this.PSVersn = (Get-Variable PSVersionTable).Value;
    $this.leadingChar = [char]9581 + [char]9592;
    $this.trailngChar = [char]9584 + [char]9588;
    $this.LogFile;
    $this.colors = $this.Get_Colors()
    # Prevent tsl errors
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    # Set the default launch ascii : chadnpc. but TODO: add a way to load it from a config instead of hardcoding it.
    $this.Default_Term_Ascii = [System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('bSUBJQElASVuJW0lbiUgACAAIAAgACAAIAAgAG0lASUBJQElbiVtJW4lCgADJW0lASVuJQMlAyUDJSAAIAAgAG0lbiUgACAAAyVtJQElbiUDJW8lcCVuJQoAAyUDJSAAAyUDJQMlbSUBJQElbiVtJW4lASVuJQMlAyUgAAMlAyVuJW0lbSUBJQElbiUBJQElbiUKAAMlcCUBJW8lAyUDJQMlbSUgAAMlfAADJW0lbiVuJQMlIAADJQMlAyUDJXwAbSVuJQMlbSUBJW8lCgADJW0lASVuJQMlAyVwJXAlbyVwJW4lAyUDJQMlAyVwJQElbyUDJQMlcCVuJQMlASUrJXAlASVuJQoAcCVvJSAAcCVvJXAlASVvJQElASVvJW8lbyVwJW8lASUBJW4lcCUBJQElbyUBJQElbyUBJQElbyUKACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIAAgACAAIABwJW8lCgAiAFEAdQBpAGMAawAgAHAAcgBvAGQAdQBjAHQAaQB2AGUAIAB0AGUAYwBoACIA'));
    $this.WINDOWS_TERMINAL_JSON_PATH = [IO.Path]::Combine($env:LocalAppdata, 'Packages', 'Microsoft.WindowsTerminal_8wekyb3d8bbwe', 'LocalState', 'settings.json');
    # Initialize or Reload $PROFILE and the core functions necessary for displaying your custom prompt.
    $p = [PSObject]::new(); Get-Variable PROFILE -ValueOnly | Get-Member -Type NoteProperty | ForEach-Object {
      $p | Add-Member -Name $_.Name -MemberType NoteProperty -Value ($_.Definition.split('=')[1] -as [IO.FileInfo])
    }
    $this.PROFILE = $p
    # Set Host UI DEFAULS
    $this.WindowTitle = $this.GetWindowTitle()
    if (!(Get-Variable OH_MY_POSH_PATH -ValueOnly -ErrorAction Ignore)) {
      New-Variable -Name OH_MY_POSH_PATH -Scope Global -Option Constant -Value ([IO.Path]::Combine($env:LOCALAPPDATA, 'Programs', 'oh-my-posh')) -Force
    }
    $this.HostOS = $(if ($(Get-Variable PSVersionTable -Value).PSVersion.Major -le 5 -or $(Get-Variable IsWindows -Value)) { "Windows" }elseif ($(Get-Variable IsLinux -Value)) { "Linux" }elseif ($(Get-Variable IsMacOS -Value)) { "MacOS" }else { "UNKNOWN" });
    $this.OmpJsonFile = [IO.FileInfo]::New([IO.Path]::Combine($(Get-Variable OH_MY_POSH_PATH -Scope Global -ValueOnly), 'themes', 'p10k_classic.omp.json'))
  }
  [void] Add_OMP_To_Profile() {
    $this.Add_OMP_To_Profile($this.GetPsProfile())
  }
  [void] Add_OMP_To_Profile([IO.FileInfo]$File) {
    Write-Host "Checking for OH_MY_POSH in Profile ... " -ForegroundColor Yellow
    if ([string]::IsNullOrWhiteSpace("$([string]$this.ompJson) ".Trim())) {
      try {
        $this.ompJson = $this.get_omp_Json()
      } catch [System.Net.Http.HttpRequestException], [System.Net.Sockets.SocketException] {
        throw [System.Exception]::New('gist.githubusercontent.com:443  Please check your internet')
      }
    }
    if (!$this.OmpJsonFile.Exists) {
      Set-Content -Path ($this.OmpJsonFile.FullName) -Value ($this.ompJson) -Force
    }
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# Enable Oh My Posh Theme Engine')
    [void]$sb.AppendLine('oh-my-posh --init --shell pwsh --config ~/AppData/Local/Programs/oh-my-posh/themes/p10k_classic.omp.json | Invoke-Expression')
    if (!(Select-String -Path $File.FullName -Pattern "oh-my-posh" -SimpleMatch -Quiet)) {
      # TODO: #3 Move configuration to directory instead of manipulating original profile file
      Write-Host "Add OH_MY_POSH to Profile ... " -NoNewline -ForegroundColor DarkYellow
      Add-Content -Path $File.FullName -Value $sb.ToString()
      Write-Host "Done." -ForegroundColor Yellow
    } else {
      Write-Host "OH_MY_POSH is added to Profile." -ForegroundColor Green
    }
  }
  [void] Set_TerminalUI() {
    (Get-Variable -Name Host -ValueOnly).UI.RawUI.WindowTitle = $this.WindowTitle
    (Get-Variable -Name Host -ValueOnly).UI.RawUI.ForegroundColor = "White"
    (Get-Variable -Name Host -ValueOnly).PrivateData.ErrorForegroundColor = "DarkGray"
  }
  [string] GetWindowTitle() {
    $Title = ($this.GetCurrentProces().Path -as [IO.FileInfo]).BaseName
    try {
      $user = [Security.Principal.WindowsIdentity]::GetCurrent()
      [void][Security.Principal.WindowsIdentity]::GetAnonymous()
      $ob = [Security.Principal.WindowsPrincipal]::new($user)
      $UserRole = [PSCustomObject]@{
        'HasUserPriv'  = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::User)
        'HasAdminPriv' = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
        'HasSysPriv'   = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::SystemOperator)
        'IsPowerUser'  = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::PowerUser)
        'IsGuest'      = [bool]$ob.IsInRole([Security.Principal.WindowsBuiltinRole]::Guest)
      }
      $UserRole.PSObject.TypeNames.Insert(0, 'Security.User.RoleProperties')
      if ($UserRole.IsPowerUser) {
        $Title += $($this.b1 + 'E' + $this.b2) # IsElevated
      }
      if ($UserRole.HasSysPriv) {
        $Title += $($this.b1 + 'S' + $this.b2) # IsSYSTEM
      }
      # Admin indicator not neded, since Windows11 build 22557.1
      if ($UserRole.HasAdminPriv) { $Title += ' (Admin)' }
      if ($UserRole.HasUserPriv -and !($UserRole.HasAdminPriv)) { $Title += ' (User)' }
    } catch [System.PlatformNotSupportedException] {
      $Title += $($this.b1 + $this.b2 + ' (User)')
    }
    return $Title
  }
  [void] Write_Term_Ascii() {
    if ($null -eq ($this.PSVersn)) { $this.Set_Defaults() }
    [double]$MinVern = 5.1
    [double]$CrVersn = ($this.PSVersn | Select-Object @{l = 'vern'; e = { "{0}.{1}" -f $_.PSVersion.Major, $_.PSVersion.Minor } }).vern
    if ($null -ne ($this.colors)) {
      Write-Host ''; # i.e: Writing to the console in 24-bit colors can only work with PowerShell versions lower than '5.1'
      if ($CrVersn -gt $MinVern) {
        # Write-ColorOutput -ForegroundColor DarkCyan $($this.Default_Term_Ascii)
        Write-Host "$($this.Default_Term_Ascii)" -ForegroundColor Green
      } else {
        $this.Write_RGB($this.Default_Term_Ascii, 'SlateBlue')
      }
      Write-Host ''
    }
  }
  [void] Resolve_Module([string[]]$names) {
    if (!$(Get-Variable Resolve_Module_fn -ValueOnly -Scope global -ErrorAction Ignore)) {
      # Write-Verbose "Fetching the Resolve_Module script (One-time/Session only)";
      Set-Variable -Name Resolve_Module_fn -Scope global -Option ReadOnly -Value ([scriptblock]::Create($((Invoke-RestMethod -Method Get https://api.github.com/gists/7629f35f93ae89a525204bfd9931b366).files.'Resolve-Module.ps1'.content)))
    }
    . $(Get-Variable Resolve_Module_fn -ValueOnly -Scope global)
    Resolve-Module -Name $Names
  }
  [void] Write_RGB([string]$Text, $ForegroundColor) {
    $this.Write_RGB($Text, $ForegroundColor, $true)
  }
  [void] Write_RGB([string]$Text, [string]$ForegroundColor, [bool]$NoNewLine) {
    $this.Write_RGB($Text, $ForegroundColor, 'Black')
  }
  [void] Write_RGB([string]$Text, [string]$ForegroundColor, [string]$BackgroundColor) {
    $this.Write_RGB($Text, $ForegroundColor, $BackgroundColor, $true)
  }
  [void] Write_RGB([string]$Text, [string]$ForegroundColor, [string]$BackgroundColor, [bool]$NoNewLine) {
    $escape = [char]27 + '['; $24bitcolors = $this.colors
    $resetAttributes = "$($escape)0m";
    $psBuild = $this.PSVersn.PSVersion.Build
    [double]$VersionNum = $($this.PSVersn.PSVersion.ToString().split('.')[0..1] -join '.')
    if ([bool]$($VersionNum -le [double]5.1)) {
      [rgb]$Background = [rgb]::new(1, 36, 86);
      [rgb]$Foreground = [rgb]::new(255, 255, 255);
      $f = "$($escape)38;2;$($Foreground.Red);$($Foreground.Green);$($Foreground.Blue)m"
      $b = "$($escape)48;2;$($Background.Red);$($Background.Green);$($Background.Blue)m"
      $f = "$($escape)38;2;$($24bitcolors.$ForegroundColor.Red);$($24bitcolors.$ForegroundColor.Green);$($24bitcolors.$ForegroundColor.Blue)m"
      $b = "$($escape)48;2;$($24bitcolors.$BackgroundColor.Red);$($24bitcolors.$BackgroundColor.Green);$($24bitcolors.$BackgroundColor.Blue)m"
      if ([bool](Get-Command Write-Info -ErrorAction SilentlyContinue)) {
        Write-Info ($f + $b + $Text + $resetAttributes) -NoNewLine:$NoNewLine
      } else {
        Write-Host ($f + $b + $Text + $resetAttributes) -NoNewline:$NoNewLine
      }
    } else {
      throw [System.Management.Automation.RuntimeException]::new("Writing to the console in 24-bit colors can only work with PowerShell versions lower than '5.1 build 14931' or above.`nBut yours is '$VersionNum' build '$psBuild'")
    }
  }
  [PsObject] GetCurrentProces() {
    $chost = Get-Variable Host -ValueOnly; $process = Get-Process -Id $(Get-Variable pid -ValueOnly) | Get-Item
    $versionTable = Get-Variable PSVersionTable -ValueOnly
    return [PsObject]@{
      Path           = $process.Fullname
      FileVersion    = $process.VersionInfo.FileVersion
      PSVersion      = $versionTable.PSVersion.ToString()
      ProductVersion = $process.VersionInfo.ProductVersion
      Edition        = $versionTable.PSEdition
      Host           = $chost.name
      Culture        = $chost.CurrentCulture
      Platform       = $versionTable.platform
    }
  }
  [void] SetConsoleTitle([string]$Title) {
    $chost = Get-Variable Host -ValueOnly
    $width = ($chost.UI.RawUI.MaxWindowSize.Width * 2)
    if ($chost.Name -ne "ConsoleHost") {
      Write-Warning "This command must be run from a PowerShell console session. Not the PowerShell ISE or Visual Studio Code or similar environments."
    } elseif (($title.length -ge $width)) {
      Write-Warning "Your title is too long. It needs to be less than $width to fit your current console."
    } else {
      $chost.ui.RawUI.WindowTitle = $Title
    }
  }
  [hashtable] Get_Colors() {
    $c = @{}; [RGB].GetProperties().Name.ForEach({ $c[$_] = [RGB]::$_ })
    return $c
  }
  hidden [void] Create_Prompt_Function() {
    # Creates the Custom prompt function & if nothing goes wrong then shows a welcome Ascii Art
    $this.CurrExitCode = $true
    try {
      # Creates the prompt function
      $null = New-Item -Path function:prompt -Value $([scriptblock]::Create({
            if (!$this.IsInitialised()) {
              Write-Verbose "[PsProfile] Initializing, Please wait ..."
              $this.Initialize()
            }
            try {
              if ($NestedPromptLevel -ge 1) {
                $this.trailngChar += [string][char]9588
                # $this.leadingChar += [string][char]9592
              }
              # Grab th current loaction
              $location = "$((Get-Variable ExecutionContext).Value.SessionState.Path.CurrentLocation.Path)";
              $shortLoc = $this.Get_Short_Path($location, $this.dt)
              $IsGitRepo = if ([bool]$(try { Test-Path .git -ErrorAction silentlyContinue }catch { $false })) { $true }else { $false }
              $(Get-Variable Host).Value.UI.Write(($this.leadingChar))
              Write-Host -NoNewline $($this.b1);
              Write-Host $([Environment]::UserName).ToLower() -NoNewline -ForegroundColor Magenta;
              Write-Host $([string][char]64) -NoNewline -ForegroundColor Gray;
              Write-Host $([System.Net.Dns]::GetHostName().ToLower()) -NoNewline -ForegroundColor DarkYellow;
              Write-Host -NoNewline "$($this.b2) ";
              if ($location -eq "$env:UserProfile") {
                Write-Host $($this.Home_Indic) -NoNewline -ForegroundColor DarkCyan;
              } elseif ($location.Contains("$env:UserProfile")) {
                $location = $($location.replace("$env:UserProfile", "$($this.swiglyChar)"));
                if ($location.Length -gt 25) {
                  $location = $this.Get_Short_Path($location, $this.dt)
                }
                Write-Host $location -NoNewline -ForegroundColor DarkCyan
              } else {
                Write-Host $shortLoc -NoNewline -ForegroundColor DarkCyan
              }
              # add a newline
              if ($IsGitRepo) {
                Write-Host $((Write-VcsStatus) + "`n")
              } else {
                Write-Host "`n"
              }
            } catch {
              #Do this if a terminating exception happens#
              # if ($_.Exception.WasThrownFromThrowStatement) {
              #     [System.Management.Automation.ErrorRecord]$_ | Write-Log $($this.LogFile.FullName)
              # }
              $(Get-Variable Host).Value.UI.WriteErrorLine("[PromptError] [$($_.FullyQualifiedErrorId)] $($_.Exception.Message) # see the Log File : $($this.LogFile.FullName) $($this.nl)")
            } finally {
              #Do this after the try block regardless of whether an exception occurred or not
              Set-Variable -Name LASTEXITCODE -Scope Global -Value $($this.realLASTEXITCODE)
            }
            Write-Host ($this.trailngChar)
          }
        )
      ) -Force
      $this.CurrExitCode = $this.CurrExitCode -and $?
    } catch {
      $this.CurrExitCode = $false
      # Write-Log -ErrorRecord $_
    } finally {
      Set-Variable -Name IsPromptInitialised -Value $($this.CurrExitCode) -Visibility Public -Scope Global;
    }
  }
  hidden [string] Get_Short_Path() {
    $curr_location = $(Get-Variable ExecutionContext).Value.SessionState.Path.CurrentLocation.Path
    return $this.get_short_Path($curr_location, 2, 2, $this.DirSeparator, [char]8230)
  }
  hidden [string] Get_Short_Path([string]$Path) {
    return $this.get_short_Path($Path, 2, 2, $this.DirSeparator, [char]8230)
  }
  hidden [string] Get_Short_Path([string]$Path, [char]$TruncateChar) {
    return $this.get_short_Path($Path, 2, 2, $this.DirSeparator, $TruncateChar)
  }
  hidden [string] Get_Short_Path([string]$Path, [int]$KeepBefore, [int]$KeepAfter, [Char]$Separator, [char]$TruncateChar) {
    # [int]$KeepBefore, # Number of parts to keep before truncating. Default value is 2.
    # [int]$KeepAfter, # Number of parts to keep after truncating. Default value is 1.
    # [Char]$Separator, # Path separator character.
    $Path = (Resolve-Path -Path $Path).Path;
    $Path = $Path.Replace(([System.IO.Path]::DirectorySeparatorChar), $this.DirSeparator)
    [ValidateRange(1, [int32]::MaxValue)][int]$KeepAfter = $KeepAfter
    $Separator = $Separator.ToString(); $TruncateChar = $TruncateChar.ToString()
    $splitPath = $Path.Split($Separator, [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($splitPath.Count -gt ($KeepBefore + $KeepAfter)) {
      $outPath = [string]::Empty
      for ($i = 0; $i -lt $KeepBefore; $i++) {
        $outPath += $splitPath[$i] + $Separator
      }
      $outPath += "$($TruncateChar)$($Separator)"
      for ($i = ($splitPath.Count - $KeepAfter); $i -lt $splitPath.Count; $i++) {
        if ($i -eq ($splitPath.Count - 1)) {
          $outPath += $splitPath[$i]
        } else {
          $outPath += $splitPath[$i] + $Separator
        }
      }
    } else {
      $outPath = $splitPath -join $Separator
      if ($splitPath.Count -eq 1) {
        $outPath += $Separator
      }
    }
    return $outPath
  }
  hidden [System.IO.DirectoryInfo] Create_Directory([string]$Path) {
    $nF = @(); $d = [System.IO.DirectoryInfo]::New((Get-Variable ExecutionContext).Value.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path))
    ([ProgressUtil]::data.ShowProgress) ? (Write-Console "Creating Directory '$($d.FullName)' ..." -f DarkKhaki) : $null
    while (!$d.Exists) { $nF += $d; $d = $d.Parent }
    [Array]::Reverse($nF); $nF | ForEach-Object { $_.Create() }
    return $d
  }
}


class dotProfile {
  #.LINK
  # https://pastebin.com/raw/rdqSxHT8
  # usage: $Banner.Write(19, $false, $true)
  static [cliart]$Banner = [cliart]::Create("H4sIAAAAAAAAA61S0QrCMAz8IF8E+wdOmBQcE22lb0Mn1FUtgvj70s7ZtOvaID4cpDlyl9Ar6odUupTqfhlDnH1ueMd6mHkMP+WR00jusNosn5TLyoKpirKuh+vNXN21lA+APex8hvd6f/V4zSnRzboH3xLdfMAbonlNND85PgY7g+ShfpTfg/qA8zAzcMf4DYXJ7Pd/y3RexE4qUfSAM2g+ph/UAuyT87BYjPVGHkeTWXZ1ufWzU1F2a/GZzfBY/XCfSQ8AlryhtpmF/wthshDmN5JpNP+LfsIjxPQNb9ytVCVoBQAA", ("Build. Ship. Repeat."))
  static [ProfileConfig]$config = @{}

  dotProfile() { }
  dotProfile([string]$Json) {
  }
  hidden [string] Get_Short_Path() {
    $curr_location = $(Get-Variable ExecutionContext).Value.SessionState.Path.CurrentLocation.Path
    return $this.get_short_Path($curr_location, 2, 2, $this.DirSeparator, [char]8230)
  }
  hidden [string] Get_Short_Path([string]$Path) {
    return $this.get_short_Path($Path, 2, 2, $this.DirSeparator, [char]8230)
  }
  hidden [string] Get_Short_Path([string]$Path, [char]$TruncateChar) {
    return $this.get_short_Path($Path, 2, 2, $this.DirSeparator, $TruncateChar)
  }
  hidden [string] Get_Short_Path([string]$Path, [int]$KeepBefore, [int]$KeepAfter, [Char]$Separator, [char]$TruncateChar) {
    # [int]$KeepBefore, # Number of parts to keep before truncating. Default value is 2.
    # [int]$KeepAfter, # Number of parts to keep after truncating. Default value is 1.
    # [Char]$Separator, # Path separator character.
    $Path = (Resolve-Path -Path $Path).Path;
    $Path = $Path.Replace(([System.IO.Path]::DirectorySeparatorChar), $this.DirSeparator)
    [ValidateRange(1, [int32]::MaxValue)][int]$KeepAfter = $KeepAfter
    $Separator = $Separator.ToString(); $TruncateChar = $TruncateChar.ToString()
    $splitPath = $Path.Split($Separator, [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($splitPath.Count -gt ($KeepBefore + $KeepAfter)) {
      $outPath = [string]::Empty
      for ($i = 0; $i -lt $KeepBefore; $i++) {
        $outPath += $splitPath[$i] + $Separator
      }
      $outPath += "$($TruncateChar)$($Separator)"
      for ($i = ($splitPath.Count - $KeepAfter); $i -lt $splitPath.Count; $i++) {
        if ($i -eq ($splitPath.Count - 1)) {
          $outPath += $splitPath[$i]
        } else {
          $outPath += $splitPath[$i] + $Separator
        }
      }
    } else {
      $outPath = $splitPath -join $Separator
      if ($splitPath.Count -eq 1) {
        $outPath += $Separator
      }
    }
    return $outPath
  }
  hidden [System.IO.DirectoryInfo] Create_Directory([string]$Path) {
    $nF = @(); $d = [System.IO.DirectoryInfo]::New((Get-Variable ExecutionContext).Value.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path))
    ([ProgressUtil]::data.ShowProgress) ? (Write-Console "Creating Directory '$($d.FullName)' ..." -f DarkKhaki) : $null
    while (!$d.Exists) { $nF += $d; $d = $d.Parent }
    [Array]::Reverse($nF); $nF | ForEach-Object { $_.Create() }
    return $d
  }
}


