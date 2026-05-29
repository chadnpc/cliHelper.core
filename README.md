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
- and many more!

<h2><b>Usage</b></h2>

```PowerShell
Install-Module cliHelper.core
```

then run demos

```PowerShell
Import-Module cliHelper.core
$still_failing = [ConsoleHelper]::Run_Interactive_Demos()
```


other examples:


```powershell
[Emoji]::Replace('Deploy :rocket: status :white_check_mark:')
# Deploy 🚀 status ✅
```

Objects preview/rendering:

```powershell
$data = [ordered]@{
  service = 'api'
  healthy = $true
  latency = 24
}

[AnsiConsole]::Console.Write([JsonText]::new($data))
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