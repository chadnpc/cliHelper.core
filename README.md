<h2>
<img align="right" width="250" height="250" alt="Icon" src="https://github.com/chadnpc/cliHelper.core/blob/main/.github/pc.png" />
</h2>
<div align="Left">
  <a href="https://www.powershellgallery.com/packages/cliHelper.core"><b>cliHelper.core</b></a>
  <p>
    A collections of essential PowerShell functions that stonks up your terminal game
    </br></br></br>
    <a href="https://github.com/chadnpc/cliHelper.core/actions/workflows/Build_on_windows.yaml">
    <img src="https://github.com/chadnpc/cliHelper.core/actions/workflows/Build_on_windows.yaml/badge.svg" alt="Build on Windows"/>
    </a>
    <a href="https://github.com/chadnpc/cliHelper.core/actions/workflows/Build_on_Mac.yaml">
    <img src="https://github.com/chadnpc/cliHelper.core/actions/workflows/Build_on_Mac.yaml/badge.svg" alt="Build on MacOS"/>
    </a>
    <a href="https://github.com/chadnpc/cliHelper.core/actions/workflows/Build_on_Linux.yaml">
    <img src="https://github.com/chadnpc/cliHelper.core/actions/workflows/Build_on_Linux.yaml/badge.svg" alt="Build on Linux"/>
    </a>
    <a href="https://www.powershellgallery.com/packages/cliHelper.core">
    <img src="https://img.shields.io/powershellgallery/dt/cliHelper.core.svg?style=flat&logo=powershell&color=blue" alt="PowerShell Gallery" title="PowerShell Gallery" />
    </a>
  </p>
</div>

## Features

**🎨 UI & Console Rendering**
- **Rich Text & Styling:** Markup, Alignment, Rules, Emojis, and full 24-bit RGB / 256-color support.
- **Complex Layouts:** Responsive Grids, Rows, Columns, Panels, and Trees.
- **Data Display:** Highly customizable Tables (6+ border styles) and syntax-highlighted JSON rendering.
- **Visualizations:** BarCharts, BreakdownCharts, Calendars, and 3D Figlet ASCII Art generation.

**⏳ Progress & Status Indicators**
- **Live Updates:** Smooth, multi-task animated Progress Bars and Spinners.
- **Status Messages:** Live display contexts and status indicators that don't break console output.

**🕹️ Interactive Prompts**
- **Input Types:** TextPrompt, ConfirmationPrompt, SelectionPrompt, and MultiSelectionPrompt.
- **Advanced Selection:** Searchable ListPrompt for filtering through large datasets interactively.
- **Convenience Cmdlets:** Wrapper cmdlets provided for all UI elements and prompts, allowing seamless integration in PowerShell scripts without needing to instantiate classes directly.

**⚙️ Background Processing**
- **ThreadRunner:** Run parallel jobs with thread-safe live console output (no more mangled text).
- **Resiliency:** `Result` pattern (borrowed from Rust) for safe, immutable error handling without throwing exceptions.
- **Retriable Tasks:** Built-in `Invoke-RetriableCommand` and background task abstractions (`New-Task`, `Wait-Task`).
- **Web & Security:** Resilient file downloading, robust REST API helpers, and native AntiVirus (AMSI) integration for attachment scanning.

<h2><b>Usage</b></h2>

```PowerShell
Install-Module cliHelper.core
```

then run demos

```PowerShell
Import-Module cliHelper.core
$any_failing_demos = [ConsoleHelper]::Run_Interactive_Demos()
$any_failing_demos.Count -eq 0 | Should -Be $true
```

## requirements

- PowerShell 7.0 or higher

## development

git clone

```PowerShell
git clone https://github.com/chadnpc/cliHelper.core.git -Depth 1 cliHelper.core
cd cliHelper.core
```

make your changes and run the following command to test your changes:

```PowerShell
Import-Module .\cliHelper.core.psd1 -ea Ignore -Verbose:$false -Force;
$pester_test_results = .\Test-Module.ps1 -NoBuild
```

## license

This project is licensed under the [WTFPL License](LICENSE).