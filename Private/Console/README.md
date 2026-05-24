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

$console = [AnsiConsole]::Console
$console.MarkupLine('[bold green]Hello from AnsiConsole[/]')
$console.Write([Panel]::new([Markup]::new('[yellow]Pure PowerShell classes[/]')))
```

## Usage Examples

### 1) Text and Markup

```powershell
$console = [AnsiConsole]::Console

$console.Write([Text]::new('Plain text output'))
$console.WriteLine('')
$console.Write([Markup]::new('[yellow]Warning:[/] disk usage high'))
$console.WriteLine('')
```

### 2) Panels, Rules, and Alignment. 

```powershell
$console = [AnsiConsole]::Console

$panel = [Panel]::new([Markup]::new('[green]Build completed[/]'))
$panel.Header = [PanelHeader]::new('CI Status')

$aligned = [Align]::Center($panel)

$console.Write([Rule]::new('Deployment'))
$console.Write($aligned)
```

### 3) Tables. 

```powershell
$table = [Table]::new()
[void]$table.AddColumn([TableColumn]::new('Name'))
[void]$table.AddColumn([TableColumn]::new('Role'))
[void]$table.AddRow(@('Harvey', 'Closer'))
[void]$table.AddRow(@('Donna', 'COO'))

[AnsiConsole]::Console.Write($table)
```

### 4) Rows, Columns, and Grid. 

```powershell
$console = [AnsiConsole]::Console

$rows = [Rows]::new(@(
  [Markup]::new('[bold]Service A[/]'),
  [Markup]::new('[dim]Healthy[/]')
))
$console.Write($rows)

$grid = [Grid]::new()
$grid.AddColumn() | Out-Null
$grid.AddColumn() | Out-Null
[void]$grid.AddRow(@(
  [Markup]::new('[bold]Region[/]'),
  [Markup]::new('[bold]Latency[/]')
))
[void]$grid.AddRow(@(
  [Text]::new('us-east-1'),
  [Markup]::new('[green]24 ms[/]')
))
[void]$grid.AddRow(@(
  [Text]::new('eu-west-1'),
  [Markup]::new('[yellow]67 ms[/]')
))

$console.Write($grid)
```

### 5) Tree Rendering.  

```powershell
$tree = [Tree]::new('Root')
$branch = $tree.Root.AddNode('Branch 1')
[void]$branch.AddNode('Leaf 1.1')
[void]$tree.Root.AddNode('Branch 2')

[AnsiConsole]::Console.Write($tree)
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
$console = [AnsiConsole]::Console

$chart = [BarChart]::new()
$chart.AddItem('API', 92, [Color]::Green) | Out-Null
$chart.AddItem('DB', 65, [Color]::Yellow) | Out-Null
$chart.AddItem('IO', 35, [Color]::Red) | Out-Null
$console.Write($chart)

$breakdown = [BreakdownChart]::new()
$breakdown.AddItem('Tests', 120, [Color]::Blue) | Out-Null
$breakdown.AddItem('Lint', 35, [Color]::Green) | Out-Null
$breakdown.AddItem('Package', 10, [Color]::Yellow) | Out-Null
$console.Write($breakdown)

$calendar = [Calendar]::new(
  [datetime]::new(2026, 5, 22),
  [datetime[]]@(
    [datetime]::new(2026, 5, 1),
    [datetime]::new(2026, 5, 15)
  )
)
$console.Write($calendar)
```

### 11) Emoji Replacement. 

```powershell
[Emoji]::Replace('Deploy :rocket: status :white_check_mark:')
# Deploy 🚀 status ✅
```

### 12) FigletText Placeholder. 

`FigletText` is still an incomplete implementation / feature-complete yet.

```powershell
$fig = [FigletText]::new([FigletFont]::DEFAULT_3D, 'ansiconsole')
[AnsiConsole]::Console.Write($fig)
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
