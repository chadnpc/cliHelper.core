Import-Module .\cliHelper.core.psd1 -Verbose:$false -Force
$failed = $false
try {
  [ConsoleHelper]::DemoProgress()
  [ConsoleHelper]::DemoFigletText()
  [ConsoleHelper]::DemoSearchableListPrompt()
  [ConsoleHelper]::DemoAnsiInThreadrunner()
  [ConsoleHelper]::DemoConfirmPrompt()
  [ConsoleHelper]::DemoMarkup()
  [ConsoleHelper]::DemoTextandMarkup()
  [ConsoleHelper]::DemoPanelsRulesandAlignment()
  [ConsoleHelper]::DemoTables()
  [ConsoleHelper]::DemoRowsColumnsandGrid()
  [ConsoleHelper]::DemoTreeRendering()
  [ConsoleHelper]::DemoJSONRendering()
  [ConsoleHelper]::DemoChartsandCalendar()
  [ConsoleHelper]::DemoTextPrompt()
  [ConsoleHelper]::DemoSelectionPrompt()
  [ConsoleHelper]::DemoMultiSelectionPrompt()
  [ConsoleHelper]::DemoConfirmPrompt()
  [ConsoleHelper]::DemoStatus()
  [ConsoleHelper]::DemoLiveStatus()
  [ConsoleHelper]::DemoProgress()
  [ConsoleHelper]::DemoFailingTaskInThreadrunner()
  [ConsoleHelper]::DemoCliArt()
} catch {
  $failed = $true
  Write-Host "An error occurred. (Message: $($_.Exception.Message))" -ForegroundColor Red
} finally {
  if ($failed) {
    Write-Host "The command failed." -ForegroundColor Red
    $Error[0] | Format-List * -Force
  } else {
    Write-Host "Commands completed successfully." -ForegroundColor Green
  }
}