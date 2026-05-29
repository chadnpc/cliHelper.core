Import-Module .\cliHelper.core.psd1 -Verbose:$false -Force
# [ConsoleHelper].GetMethods().Where({ $_.IsStatic -and $_.Name.StartsWith("Demo") }).Name
$demos = @{
  DemoMarkup                                 = "Markup rendering"
  DemoTextandMarkup                          = "Detect text and Markup"
  DemoPanelsRulesandAlignment                = "Panels, Rules, and Alignment."
  DemoTables                                 = "Tables."
  DemoRowsColumnsandGrid                     = "Rows, Columns, and Grid."
  DemoTreeRendering                          = "Tree Rendering."
  DemoJSONRendering                          = "JSON preview/rendering."
  DemoChartsandCalendar                      = "Charts and Calendar."
  DemoProgress                               = "Animated Progress."
  DemoFigletText                             = "FigletText Placeholder."
  DemoSearchableListPrompt                   = "Searchable Interactive ListPrompt."
  DemoAnsiInThreadrunner                     = "Ansi color ouptut in Threadrunner"
  DemoFailingTaskInThreadrunner              = "How threadrunner handles failing tasks"
  DemoSimultaneousBackgroundJobsWithFailures = "Simultaneous Background Jobs with Failures"
  DemoStatus                                 = "Status with Spinner." # failing - crashing
  DemoTextPrompt                             = "Text Prompt"
  DemoConfirmPrompt                          = "Confirmation Prompt"
  DemoSelectionPrompt                        = "Selection Prompt"
  DemoMultiSelectionPrompt                   = "MultiSelection Prompt"
  DemoCliArt                                 = "CliArt"
}
$errors = [System.Collections.Generic.List[ErrorRecord]]::new()
$demos.Keys.ForEach({
    Write-Console "[+] " -NoNewLine; Write-Console $demos[$_] -f LimeGreen
    try {
      [ConsoleHelper]::$_()
    } catch {
      $errors.Add($_)
    } finally {
      $Host.UI.WriteLine()
    }
  }
)
return $errors.ToArray()