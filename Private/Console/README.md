# Console sub-module

Contains pure classes for providing beautiful console UI elements without external dependencies.

## Features
- Core rendering pipeline (ANSI codes, colors, styles, decorations)
- Text widgets (Text, Markup, Paragraph, Align, Panel, Box, Rule)
- Tables with 6+ border styles
- Basic Charts (BarChart, BreakdownChart)
- Tree and Grid layouts
- Progress bars, live updates, and Status indicators
- Interactive prompts (TextPrompt, ConfirmationPrompt, SelectionPrompt, MultiSelectionPrompt)
- JSON tokenization, parsing, and syntax-highlighted rendering
- Searchable ListPrompt
- Full color system (256 + RGB support)

## Quick Start

```powershell
Import-Module .\cliHelper.core.psd1 -Verbose -Force
[ConsoleHelper]::DemoMarkup()
```

## Usage Examples

### 1) Text and Markup

```powershell
[ConsoleHelper]::DemoTextandMarkup()
```

### 2) Panels, Rules, and Alignment. 

```powershell
[ConsoleHelper]::DemoPanelsRulesandAlignment()
```

### 3) Tables. 

```powershell
[ConsoleHelper]::DemoTables()
```

### 4) Rows, Columns, and Grid. 

```powershell
[ConsoleHelper]::DemoRowsColumnsandGrid()
```

### 5) Tree Rendering.  

```powershell
[ConsoleHelper]::DemoTreeRendering()
```

### 6) Spinner Definitions. 

```powershell
$spinner = [SpinnerKnown]::Earth
"Spinner: $($spinner.Name)"
"Frames : $($spinner.Frames -join ' ')"
"Interval: $($spinner.Interval.TotalMilliseconds) ms"
```

### 7) Progress. 

```powershell
$console = [AnsiConsole]::Console
$progress = [Progress]::new($console)
$progress.RefreshRateMs = 80

$progress.Start([Action[ProgressContext]]{
  param([ProgressContext]$ctx)

  $task = $ctx.AddTask('Loading data', [ProgressTaskSettings]::new())
  foreach ($step in 1..5) {
    Start-Sleep -Milliseconds 120
    $task.Increment(20)
  }
})
```

### 8) Status with Spinner. 

```powershell
$writer = [AnsiConsole]::Console.Writer
$status = [Status]::new($writer)
$status.Spinner = [SpinnerKnown]::Dots
$status.RefreshRateMs = 80

$status.Start('Downloading metadata', [Action[StatusContext]]{
  param([StatusContext]$ctx)

  Start-Sleep -Milliseconds 150
  $ctx.Update('Finishing download')
  Start-Sleep -Milliseconds 150
})
```

### 9) Prompts. 
These prompt classes require the user to manually run them in an interactive terminal because they use `Console.ReadKey()`.

```powershell
$console = [AnsiConsole]::Console

$textPrompt = [TextPrompt]::new([string], 'Environment')
$textPrompt.DefaultValue = 'dev'
# $envName = $textPrompt.Show($console);

$confirm = [ConfirmationPrompt]::new('Deploy now?')
$confirm.DefaultValue = $false
# $shouldDeploy = $confirm.Show($console);

$selection = [SelectionPrompt]::new('Pick a region')
$selection.AddChoice('US East', 'us-east-1')
$selection.AddChoice('EU West', 'eu-west-1')
$selection.AddChoice('AP South', 'ap-south-1')
# $region = $selection.Show($console);

$multi = [MultiSelectionPrompt]::new('Select components')
$multi.AddChoice('API', 'api')
$multi.AddChoice('Worker', 'worker')
$multi.AddChoice('Scheduler', 'scheduler')
# $components = $multi.Show($console);
```

### 10) Charts and Calendar. 

```powershell
[ConsoleHelper]::DemoChartsandCalendar()
```

### 11) Emoji Replacement. 

```powershell
[Emoji]::Replace('Deploy :rocket: status :white_check_mark:')
# Deploy 🚀 status ✅
```

### 12) FigletText Placeholder. 

`FigletText` is still an incomplete implementation / feature-complete yet.

```powershell
[ConsoleHelper]::DemoFigletText()
```

### 13) JSON Rendering. 

```powershell
$json = '{"name":"Ada","count":3,"ok":true,"items":[null,2]}'
$tokens = [JsonTokenizer]::Tokenize($json)
$syntax = [JsonParser]::Parse($tokens)

[AnsiConsole]::Console.Write([JsonText]::new($syntax))
```

Objects can also be rendered directly:

```powershell
$data = [ordered]@{
  service = 'api'
  healthy = $true
  latency = 24
}

[AnsiConsole]::Console.Write([JsonText]::new($data))
```

### 14) Searchable ListPrompt. Interactive ✅

```powershell
$prompt = [ListPrompt]::new('Pick a service')
$prompt.AddItems([string[]]@('api', 'worker', 'scheduler', 'gateway'))
# $service = $prompt.Show([AnsiConsole]::Console)

# Non-interactive preview for tests and docs:
$prompt.SearchFilter = 'work'
$prompt.Preview()
```

## Compatibility Notes

- Requires PowerShell Core.
- Some behaviors are still being refined for Spectre parity; see `Plan.md`.
- Prompt classes require an interactive terminal for `Console.ReadKey` flows.

## Project Roadmap / Progress

- Current implementation plan and checklist: `./Plan.md`
