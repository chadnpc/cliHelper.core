Import-Module .\cliHelper.core.psd1 -Verbose:$false -Force
# [ConsoleHelper].GetMethods().Where({ $_.IsStatic -and $_.Name.StartsWith("Demo") }).Name
$failed = $false
try {
  [ConsoleHelper]::DemoMarkup()
  [ConsoleHelper]::DemoTextandMarkup()
  [ConsoleHelper]::DemoPanelsRulesandAlignment()
  [ConsoleHelper]::DemoTables()
  [ConsoleHelper]::DemoRowsColumnsandGrid()
  [ConsoleHelper]::DemoTreeRendering()
  [ConsoleHelper]::DemoJSONRendering()
  [ConsoleHelper]::DemoChartsandCalendar()
  [ConsoleHelper]::DemoProgress()
  [ConsoleHelper]::DemoFigletText()
  [ConsoleHelper]::DemoSearchableListPrompt()
  [ConsoleHelper]::DemoAnsiInThreadrunner()
  [ConsoleHelper]::DemoFailingTaskInThreadrunner()
  [ConsoleHelper]::DemoStatus() # failing - crashing
  [ConsoleHelper]::DemoTextPrompt()
  [ConsoleHelper]::DemoConfirmPrompt()
  [ConsoleHelper]::DemoSelectionPrompt()
  [ConsoleHelper]::DemoMultiSelectionPrompt()
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