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

<h2><b>Usage</b></h2>

```PowerShell
Install-Module cliHelper.core
```

then

```PowerShell
Import-Module cliHelper.core

$art = Create-CliArt "https://pastebin.com/raw/p29UR385" -Taglines "Build. Ship. Repeat."; $art.Replace("x.y.z", "0.3.2");
$art.Write(15, $false, $true)

$RequestParams = @{
  Uri    = 'https://jsonplaceholder.typicode.com/todos/1'
  Method = 'GET'
}
$result = [ProgressUtil]::WaitJob("Making a request", { Param($rp) Start-Sleep -Seconds 2; Invoke-RestMethod @rp }, $RequestParams) | Receive-Job
echo $result
```

<!--
https://github.com/user-attachments/assets/2a8c8688-2483-4a44-8801-37fde5016306
-->

## development

git clone

```PowerShell
git clone https://github.com/chadnpc/cliHelper.core.git -Depth 1 cliHelper.core
cd cliHelper.core
```

make your changes and run the following command to test your changes:

```PowerShell
Import-Module .\cliHelper.core.psd1 -ea Ignore -Verbose:$false -Force; $pester_test_results = .\Test-Module.ps1 -NoBuild
```

## license

This project is licensed under the [WTFPL License](LICENSE).