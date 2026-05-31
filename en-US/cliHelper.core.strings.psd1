
@{
  ModuleName    = 'cliHelper.core'
  ModuleVersion = [version]'0.3.2'
  ReleaseNotes  = '# Release Notes

## Version _0.3.2_

### changelog
**🎨 UI & Console Rendering**
- Added Rich Text & Styling (Markup, Alignment, Rules, Emojis, and full 24-bit RGB / 256-color support).
- Added Complex Layouts (Responsive Grids, Rows, Columns, Panels, and Trees).
- Added Data Display (Highly customizable Tables (6+ border styles) and syntax-highlighted JSON rendering).
- Added Visualizations (BarCharts, BreakdownCharts, Calendars, and 3D Figlet ASCII Art generation).

**⏳ Progress & Status Indicators**
- Added Live Updates (Smooth, multi-task animated Progress Bars and Spinners).
- Added Status Messages (Live display contexts and status indicators that dont break console output).

**🕹️ Interactive Prompts**
- Added Input Types (TextPrompt, ConfirmationPrompt, SelectionPrompt, and MultiSelectionPrompt).
- Added Advanced Selection (Searchable ListPrompt for filtering through large datasets interactively).
- Added Convenience Cmdlets (Wrapper cmdlets provided for all UI elements and prompts, allowing seamless integration in PowerShell scripts without needing to instantiate classes directly).

**⚙️ Background Processing**
- Added ThreadRunner (Run parallel jobs with thread-safe live console output (no more mangled text).
  - Added Resiliency (`Result` pattern (borrowed from Rust) for safe, immutable error handling without throwing exceptions.
  - Added Retriable Tasks (Built-in `Invoke-RetriableCommand` and background task abstractions (`New-Task`, `Wait-Task`).
  - Added Web & Security (Resilient file downloading, robust REST API helpers, and native AntiVirus (AMSI) integration for attachment scanning).
- optimised Write-Console and others.
- Added ErrorManager
'
}
