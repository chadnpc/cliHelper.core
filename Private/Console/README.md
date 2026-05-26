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
[ConsoleHelper]::DemoProgress()
```

### 8) Status with Spinner.

```powershell
[ConsoleHelper]::DemoStatus()
```

### 9) Prompts.
These prompt classes require the user to manually run them in an interactive terminal because they use `Console.ReadKey()`.

```powershell

[ConsoleHelper]::DemoTextPrompt()

[ConsoleHelper]::DemoConfirmPrompt()

[ConsoleHelper]::DemoSelectionPrompt()

[ConsoleHelper]::DemoMultiSelectionPrompt()
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
[ConsoleHelper]::DemoJSONRendering()
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
[ConsoleHelper]::DemoSearchableListPrompt()
```

## Compatibility Notes

- Requires PowerShell Core.
- Some behaviors are still being refined for Spectre parity; see `Plan.md`.
- Prompt classes require an interactive terminal for `Console.ReadKey` flows.

## Project Roadmap / Progress

- Current implementation plan and checklist: `./Plan.md`
