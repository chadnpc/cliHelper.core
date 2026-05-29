function Start-ProcessAsAdmin {
  <#
    .SYNOPSIS
    Runs an executable with elevated (administrator) privileges.

    .DESCRIPTION
    Launches an external process, optionally requesting UAC elevation via the
    "RunAs" verb. When the target executable is 'powershell' or 'pwsh', the
    supplied statements are Base64-encoded and forwarded as an -EncodedCommand
    so that quoting and special characters are preserved.

    Standard output and standard error are captured asynchronously (using the
    ReadToEndAsync pattern) to prevent the deadlock that can occur when mixing
    synchronous reads with WaitForExit on Windows.

    .INPUTS
    None

    .OUTPUTS
    System.Int32
    The process exit code.

    .PARAMETER Statements
    Arguments to pass to ExeToRun, or a PowerShell script block expressed as
    a string when ExeToRun is 'powershell' / 'pwsh'.

    .PARAMETER ExeToRun
    The executable to launch. Defaults to 'powershell'.
    Pass 'pwsh' to target PowerShell 7+.

    .PARAMETER Elevated
    When specified, the "RunAs" verb is set on the ProcessStartInfo, prompting
    UAC elevation. Has no effect if the current session is already elevated.

    .PARAMETER Minimized
    Start the process window in a minimised state.

    .PARAMETER NoSleep
    For PowerShell targets only – omits the post-execution Start-Sleep so the
    spawned window closes immediately.

    .PARAMETER ValidExitCodes
    Exit codes that are treated as success. Defaults to @(0).

    .PARAMETER WorkingDirectory
    Working directory for the launched process. Defaults to the current
    FileSystem provider path, falling back to $env:TEMP for UNC paths.

    .PARAMETER SensitiveStatements
    Additional arguments appended to the command line that must not be logged.

    .PARAMETER IgnoredArguments
    Catch-all for splatted arguments that do not apply to this cmdlet.

    .EXAMPLE
    Start-ProcessAsAdmin -Statements '/i "setup.msi" /qn' -ExeToRun 'msiexec'

    .EXAMPLE
    Start-ProcessAsAdmin -Statements '/S' -ExeToRun 'C:\installers\app.exe' -ValidExitCodes @(0, 3010)

    .EXAMPLE
    # Run a PowerShell script block with elevation
    $psFile = Join-Path $PSScriptRoot 'someInstall.ps1'
    Start-ProcessAsAdmin "& '$psFile'"

    .EXAMPLE
    # cmd.exe with spaces in path
    $appPath = "$env:ProgramFiles\myapp"
    Start-ProcessAsAdmin -Statements "/c `"$appPath\bin\install.bat`"" -ExeToRun 'cmd'

    .LINK
    https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo
  #>
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([System.Int32])]
  param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string[]] $Statements,

    [Parameter(Mandatory = $false, Position = 1)]
    [string] $ExeToRun = 'powershell',

    [Parameter(Mandatory = $false)]
    [switch] $Elevated,

    [Parameter(Mandatory = $false)]
    [switch] $Minimized,

    [Parameter(Mandatory = $false)]
    [switch] $NoSleep,

    [Parameter(Mandatory = $false)]
    [int[]] $ValidExitCodes = @(0),

    [Parameter(Mandatory = $false)]
    [string] $WorkingDirectory,

    [Parameter(Mandatory = $false)]
    [string] $SensitiveStatements = '',

    # Catch-all so callers can safely splat extra parameters.
    [Parameter(Mandatory = $false, ValueFromRemainingArguments = $true)]
    [object[]] $IgnoredArguments
  )

  process {
    $fxn = $MyInvocation.MyCommand.Name

    #region Resolve working directory
    if ([string]::IsNullOrEmpty($WorkingDirectory)) {
      $fsLocation = Get-Location -PSProvider FileSystem -ErrorAction SilentlyContinue
      if ($null -ne $fsLocation -and -not [string]::IsNullOrEmpty($fsLocation.ProviderPath)) {
        $WorkingDirectory = $fsLocation.ProviderPath
      } else {
        Write-Debug "$fxn : Current location is not a FileSystem path. Falling back to TEMP."
        $WorkingDirectory = $env:TEMP
      }
    }
    #endregion

    #region Elevation check
    $currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    if (-not $isAdmin -and -not $Elevated) {
      Write-Error "`n$fxn : The current session is not elevated and -Elevated was not specified. `nRe-run as administrator or pass -Elevated to request UAC elevation."
      return
    }
    #endregion

    #region Sanitise inputs – strip null characters that can break argument passing
    try {
      if ($null -ne $ExeToRun) { $ExeToRun = $ExeToRun -replace "`0", '' }
      $Statements = $Statements | Where-Object { $null -ne $_ } |
        ForEach-Object { $_ -replace "`0", '' }
    } catch {
      Write-Debug "$fxn : Null-character removal failed – $($_.Exception.Message)"
    }

    if ($null -ne $ExeToRun) {
      $ExeToRun = $ExeToRun.Trim().Trim("'").Trim('"')
    }
    #endregion

    #region Resolve executable
    $isPowerShell = $ExeToRun -in @('powershell', 'pwsh')

    if (-not $isPowerShell) {
      # Expand common shorthand names
      if ($ExeToRun -in @('msiexec', 'msiexec.exe')) {
        $ExeToRun = Join-Path $env:SystemRoot 'System32\msiexec.exe'
      }

      if (-not [System.IO.File]::Exists($ExeToRun)) {
        # Try to locate via PATH before warning
        $resolved = Get-Command $ExeToRun -ErrorAction SilentlyContinue
        if ($resolved) {
          $ExeToRun = $resolved.Source
        } else {
          Write-Warning "$fxn : Cannot verify '$ExeToRun' exists. Ensure the full path is supplied."
        }
      }

      # Reject disguised text files
      $isTextMarker = [System.IO.Path]::GetFullPath($ExeToRun) + '.istext'
      if ([System.IO.File]::Exists($isTextMarker)) {
        throw "$fxn : '$ExeToRun' appears to be a text file masquerading as an executable."
      }
    }
    #endregion

    #region Build final arguments
    $joinedStatements = ($Statements -join ' ')
    $wrappedStatements = $joinedStatements

    $dbMessagePrepend = if ($Elevated) { 'Elevating permissions and running' } else { 'Running' }

    if ($isPowerShell) {
      # Prefer pwsh (PS 7+) when asked, or fall back to Windows PowerShell
      if ($ExeToRun -eq 'pwsh') {
        $resolvedPwsh = Get-Command 'pwsh' -ErrorAction SilentlyContinue
        $ExeToRun = if ($resolvedPwsh) { $resolvedPwsh.Source } else {
          Write-Warning "$fxn : 'pwsh' not found on PATH; falling back to Windows PowerShell."
          Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        }
      } else {
        $ExeToRun = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
      }

      $sleepOnSuccess = if ($NoSleep) { '' } else { 'Start-Sleep -Seconds 6' }
      $sleepOnError = if ($NoSleep) { '' } else { 'Start-Sleep -Seconds 8' }

      $block = @"
`$ProgressPreference = 'SilentlyContinue'
try {
    $joinedStatements
    $sleepOnSuccess
} catch {
    $sleepOnError
    throw
}
"@
      $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($block))
      $wrappedStatements = "-NoLogo -NonInteractive -NoProfile -ExecutionPolicy Bypass -InputFormat Text -OutputFormat Text -EncodedCommand $encoded"

      Write-Debug @"
$dbMessagePrepend PowerShell block:
$block
"@
    } else {
      Write-Debug "$dbMessagePrepend [`"$ExeToRun`" $wrappedStatements]"
    }
    #endregion

    #region Configure ProcessStartInfo
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $ExeToRun
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardInput = $true   # prevents the child from blocking on stdin
    $psi.CreateNoWindow = $false
    $psi.WorkingDirectory = $WorkingDirectory

    # UTF-8 to avoid mojibake from tools that emit non-ASCII characters
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    # Argument passing – prefer ArgumentList (PS 6.1+ / .NET Core 2.1+) to avoid
    # manual shell-quoting bugs; fall back to the Arguments string otherwise.
    $allArgs = @()
    if (-not [string]::IsNullOrEmpty($wrappedStatements)) {
      $allArgs += $wrappedStatements
    }
    if (-not [string]::IsNullOrEmpty($SensitiveStatements)) {
      $allArgs += $SensitiveStatements   # not logged above
    }

    if ($psi.ArgumentList -is [System.Collections.Generic.ICollection[string]]) {
      # Structured argument list avoids double-quoting issues on .NET Core+
      foreach ($arg in $allArgs) { $psi.ArgumentList.Add($arg) }
    } else {
      # Legacy path – escape and join
      $escapedArgs = $allArgs | ForEach-Object {
        $s = $_ -replace '(\\+)"', '$1$1"'      # escaped backslash before quote
        $s = $s -replace '(\\+)$', '$1$1'       # trailing backslashes
        $s = $s -replace '"', '\"'              # literal double-quotes
        "`"$s`""
      }
      $psi.Arguments = $escapedArgs -join ' '
    }

    # Elevation
    if ($Elevated -and -not $isAdmin -and [Environment]::OSVersion.Version -ge [Version]'6.0') {
      Write-Debug "$fxn : Setting RunAs verb for UAC elevation."
      $psi.Verb = 'RunAs'
      # RunAs requires ShellExecute; adjust accordingly
      $psi.UseShellExecute = $true
      $psi.RedirectStandardOutput = $false
      $psi.RedirectStandardError = $false
      $psi.RedirectStandardInput = $false
    }

    if ($Minimized) {
      $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized
    }
    #endregion

    #region Launch and wait
    if (-not $PSCmdlet.ShouldProcess("$ExeToRun $wrappedStatements", 'Start process')) {
      return
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $psi

    try {
      [void]$process.Start()
    } catch {
      throw "$fxn : Failed to start '$ExeToRun'. $_"
    }

    $exitCode = 0

    if ($psi.RedirectStandardOutput) {
      # ReadToEndAsync avoids the deadlock that can occur when mixing
      # synchronous reads with WaitForExit on Windows (output/error buffers fill
      # up and the child blocks waiting for us to drain them).
      $stdoutTask = $process.StandardOutput.ReadToEndAsync()
      $stderrTask = $process.StandardError.ReadToEndAsync()

      [void]$process.WaitForExit()

      $stdout = $stdoutTask.GetAwaiter().GetResult().Trim()
      $stderr = $stderrTask.GetAwaiter().GetResult().Trim()

      if (-not [string]::IsNullOrEmpty($stdout)) {
        Write-Verbose $stdout
      }
      if (-not [string]::IsNullOrEmpty($stderr)) {
        # Write to the error stream but don't throw – callers use ValidExitCodes
        $Host.UI.WriteErrorLine($stderr)
      }
    } else {
      # ShellExecute / elevated path: no stream redirection available
      [void]$process.WaitForExit()
    }

    $exitCode = $process.ExitCode
    $process.Dispose()

    Write-Debug "$fxn : [`"$ExeToRun`" $wrappedStatements] exited with '$exitCode'."
    #endregion

    #region Exit code interpretation
    # Map well-known installer exit codes to human-readable messages.
    # Sources:
    #   NSIS  – http://nsis.sourceforge.net/Docs/AppendixD.html
    #   InnoSetup – https://jrsoftware.org/ishelp/index.php?topic=setupexitcodes
    #   MSI   – https://learn.microsoft.com/en-us/windows/win32/msi/error-codes
    $knownExitMessages = @{
      2    = 'Setup was cancelled.'
      3    = 'A fatal error occurred when preparing or moving to next install phase. Ensure sufficient memory is available and retry.'
      4    = 'A fatal error occurred during the installation process.'
      5    = 'User cancelled the installation.'
      6    = 'Setup process was forcefully terminated by a debugger.'
      7    = 'Setup determined it cannot proceed with the installation. Verify system requirements.'
      8    = 'Setup requires a system restart before proceeding. Reboot and retry.'
      1602 = 'User cancelled the installation (MSI).'
      1603 = 'Generic MSI error. A pending reboot may be required, or the same version is already installed.'
      1618 = 'Another installation is currently in progress. Retry later.'
      1619 = 'MSI package could not be found or is corrupt.'
      1620 = 'MSI package could not be opened or is corrupt.'
      1622 = 'Invalid log file path specified in install arguments.'
      1623 = 'This MSI does not support the system locale.'
      1625 = 'Installation forbidden by system policy.'
      1632 = 'Installation not supported on this platform or architecture.'
      1633 = 'Installation not supported on this platform or architecture.'
      1638 = 'A different version of this product is already installed; uninstall it first.'
      1639 = 'Invalid command-line arguments passed to the MSI.'
      1640 = 'Cannot install MSI from a Remote Desktop (terminal services) session.'
      1645 = 'Cannot install MSI from a Remote Desktop (terminal services) session.'
    }

    $exitErrorMessage = $knownExitMessages[$exitCode]
    if ($exitErrorMessage) {
      Write-Warning "$fxn : Exit code $exitCode – $exitErrorMessage"
    }

    if ($ValidExitCodes -notcontains $exitCode) {
      $detail = if ($exitErrorMessage) {
        "Exit code indicates: $exitErrorMessage"
      } else {
        'See verbose/error output for details.'
      }
      throw "$fxn : Process [`"$ExeToRun`"] exited with code '$exitCode'. $detail"
    }
    #endregion

    Write-Debug "$fxn : Completed successfully."
    return $exitCode
  }
}
