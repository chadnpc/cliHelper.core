Describe "Integration tests: cliHelper.core" {
  BeforeAll {
    Import-Module "$PSScriptRoot\..\cliHelper.core.psm1" -Force
  }

  Context "Module Installation" {
    It "Should import without errors" {
      $module = Get-Module -name cliHelper.core
      $module | Should Not BeNullOrEmpty
    }
  }
}

