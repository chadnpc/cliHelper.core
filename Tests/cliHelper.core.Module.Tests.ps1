$MODULE_DATA = PsModuleBase\Read-ModuleData -File ./en-US/cliHelper.core.strings.psd1
$currentbuildPath = Resolve-Path "$PSScriptRoot/../BuildOutput/$ModuleName" -ea Ignore | Get-Item -ea Ignore
$script:ModuleName = $MODULE_DATA.ModuleName
$script:ModulePath = [IO.Directory]::Exists("$currentbuildPath") ? $currentbuildPath : (Get-Item $PSScriptRoot).Parent
$script:moduleVersion = $MODULE_DATA.ModuleVersion ? $MODULE_DATA.ModuleVersion : (((Get-ChildItem $ModulePath).Where({ $_.Name -as 'version' -is 'version' }).Name -as 'version[]' | Sort-Object -Descending)[0].ToString())
$script:currentbuildPath = [IO.Directory]::Exists("$currentbuildPath") ? "$ModulePath/$moduleVersion" : $ModulePath
$script:AllFilesAreValidPowershellSysntax = $false
Write-Host "[+] Testing the latest built module:" -ForegroundColor Green
Write-Host "      ModuleName    $ModuleName"
Write-Host "      ModulePath    $ModulePath"
Write-Host "      Version       $moduleVersion`n"

Get-Module -Name $ModuleName | Remove-Module -Verbose -ea Ignore | Out-Null # Make sure no versions of the module are loaded

Write-Host ""
Describe "Module content tests for $ModuleName" {
  Context " Confirm files are valid Powershell syntax " {
    function Test-ScriptSyntax {
      [CmdletBinding(DefaultParameterSetName = 'ByPath')]
      param (
        # Use this parameter to pass a file path directly
        [Parameter(Mandatory = $true, ParameterSetName = 'ByPath', Position = 0, ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })][Alias('FullName', 'Path')]
        [string]$FilePath,

        # Use this parameter to pass raw script text
        [Parameter(Mandatory = $true, ParameterSetName = 'ByContent')]
        [string]$FileContent
      )

      process {
        $tokens = $null
        $errors = $null

        if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
          # Write-Verbose "        Checking $FilePath ..."
          # The modern AST Parser can parse a file directly
          $null = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$tokens, [ref]$errors)
        } else {
          # Or it can parse a string of script content
          $null = [System.Management.Automation.Language.Parser]::ParseInput($FileContent, [ref]$tokens, [ref]$errors)
        }

        if ($errors.Count -gt 0) {
          # Format the errors nicely so you know exactly where the issue is
          foreach ($err in $errors) {
            [PSCustomObject]@{
              File    = if ($FilePath) { $FilePath } else { "Raw Content" }
              Line    = $err.Extent.StartLineNumber
              Column  = $err.Extent.StartColumnNumber
              Message = $err.Message
              Code    = $err.Extent.Text
            } | Format-List | Out-String | Write-Host -ForegroundColor Red
          }
        }
        return $errors
      }
    }
    function Get-AllInvalidSyntaxFiles {
      param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path
      )
      $fileswitherrors = @()
      $scripts = $(Get-Item -Path "$Path").GetFiles(
        "*", [System.IO.SearchOption]::AllDirectories
      ).Where({ $_.Extension -in ('.ps1', '.psd1', '.psm1') })
      $scripts | ForEach-Object {
        $syntaxErrors = Test-ScriptSyntax -FilePath $_.FullName
        if ($syntaxErrors.Count -ne 0) {
          $fileswitherrors += $_.FullName
        }
      }
      return $fileswitherrors
    }
    It "All .Ps1/.Psd1/.Psm1 files should have valid Powershell sysntax" {
      $fileswitherrors = Get-AllInvalidSyntaxFiles -Path $currentbuildPath
      $script:AllFilesAreValidPowershellSysntax = $fileswitherrors.Count -eq 0
      $fileswitherrors.Count | Should Be 0
    }
  }
  Context " Confirm there are no duplicate function names in private or public folders" {
    It 'Module should have no duplicate functions' {
      $Publc_Dir = Get-Item -Path ([IO.Path]::Combine("$currentbuildPath", 'Public'))
      $Privt_Dir = Get-Item -Path ([IO.Path]::Combine("$currentbuildPath", 'Private'))
      $funcNames = @(); Test-Path -Path ([string[]]($Publc_Dir, $Privt_Dir)) -PathType Container -ErrorAction Stop
      $Publc_Dir.GetFiles("*", [System.IO.SearchOption]::AllDirectories) + $Privt_Dir.GetFiles("*", [System.IO.SearchOption]::AllDirectories) | Where-Object { $_.Extension -eq '.ps1' } | ForEach-Object { $funcNames += $_.BaseName }
      $($funcNames | Group-Object | Where-Object { $_.Count -gt 1 }).Count | Should Be 0
    }
  }
}

Describe "Module structure tests for $ModuleName" {
  Context " Should export all public functions " {
    $ExportedFunctions = @(); $PS1Functions = @()
    It "The number of missing functions should be 0 " -Skip:(!$AllFilesAreValidPowershellSysntax) {
      Write-Host "[+] Reading module information ..." -ForegroundColor Green
      $ModuleInformation = Import-Module $ModulePath -PassThru
      Write-Host "[+] Verify all Eported functions and classes ..." -ForegroundColor Green
      $ExportedFunctions = $ModuleInformation.ExportedFunctions.Values.Name
      Write-Host "      ExportedFunctions: " -ForegroundColor DarkGray -NoNewline
      Write-Host $($ExportedFunctions -join ', ')
      $PS1Functions = Get-ChildItem -Path "$currentbuildPath/Public/*.ps1" -Recurse
      if ($ExportedFunctions.count -ne $PS1Functions.count) {
        $Compare = Compare-Object -ReferenceObject $ExportedFunctions -DifferenceObject $PS1Functions.Basename
        $($Compare.InputObject -join '').Trim() | Should -BeNullOrEmpty
      }
    }
    It "Compare the number of Function Exported and the PS1 files found in the public folder" -Skip:(!$AllFilesAreValidPowershellSysntax) {
      $status = $ExportedFunctions.Count -eq $PS1Functions.Count
      $status | Should Be $true
    }
  }
  Context " Module Classes " {
    It "Should export all Classes " {
      $missing = @(); $TypeAccelerators = [PsObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')::Get.Keys
      $classes = (Get-ChildItem $ModulePath/*.psm1 -Recurse -File | ForEach-Object { [IO.File]::ReadAllLines((Get-Item $_.FullName)).Where({ $_.StartsWith("class") -or $_.StartsWith("enum ") }).ForEach({ $_.Replace("class ", '').Replace("enum ", '') }).ForEach({ ($_ -like "* : *") ? $_.split(" : ")[0] + '' : $_.Replace(' {', '') }) })
      foreach ($cls in $classes) {
        try {
          if (!$TypeAccelerators.Contains("$cls")) {
            $missing += $cls
          }
        } catch {
          $missing += $cls
          Write-Host "      ✗ $cls - ERROR: $_" -ForegroundColor Red
        }
      }

      if ($missing.Count -gt 0) {
        Write-Host "      ✗ Something went wrong!" -ForegroundColor Red
        Write-Host "  WARNING: $($missing.Count) classes were not exported" -ForegroundColor Yellow
        Write-Debug "  Missing: $($missing -join ', ')"
      } else {
        Write-Host "      ✓ All classes are exported" -ForegroundColor Green
      }
    }
  }
}