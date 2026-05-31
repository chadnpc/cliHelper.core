Describe "Integration tests: cliHelper.core" {
  Context "Functionality Integration - Output Cmdlets" {
    It "Can output markup" {
      { Write-Markup -MarkupText "[green]Test Markup[/]" } | Should Not Throw
    }
    It "Can output panels" {
      { Write-Panel -Text "[red]Panel Content[/]" -Header "Test Header" } | Should Not Throw
    }
    It "Can output rules" {
      { Write-Rule -Title "Rule Title" } | Should Not Throw
    }
    It "Can output tables" {
      { Write-Table -Columns @("Column A", "Column B") -Rows @(@("1", "2"), @("3", "4")) } | Should Not Throw
    }
    It "Can output figlet text" {
      { Write-Figlet -Text "Figlet Test" } | Should Not Throw
    }
    It "Can output rows" {
      { Write-Rows -Items @("[blue]Row 1[/]", "[yellow]Row 2[/]") } | Should Not Throw
    }
    It "Can output grids" {
      { Write-Grid -Columns 2 -Rows @(@("Col1", "Col2"), @("Val1", "Val2")) } | Should Not Throw
    }
  }

  Context "Functionality Integration - Dynamic Renderables" {
    It "Can show progress" {
      {
        Show-Progress -Activity "Testing Progress Cmdlet" -Action {
          param([ProgressContext]$ctx)
          $task = $ctx.AddTask("Testing", [ProgressTaskSettings]::new())
          $task.Increment(100)
        }
      } | Should Not Throw
    }
    It "Can show status" {
      {
        Show-Status -StatusText "Testing Status Cmdlet" -Action {
          param([StatusContext]$ctx)
          $ctx.Update("Completed!")
        }
      } | Should Not Throw
    }
  }
  Context "Functionality Integration - Runner module" {
    It "Can invoke retriable commands with Result class" {
      $Result = Invoke-RetriableCommand -ScriptBlock { return 0 } -MaxAttempts 1 -Message "Test Retriable"
      $Result.IsSuccess | Should Be $true
    }
  }
}
