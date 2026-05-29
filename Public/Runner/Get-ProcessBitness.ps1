function Get-ProcessBitness {
  <#
  .SYNOPSIS
    Tests if a process is 32-bit or 64-bit.
  .DESCRIPTION
    Retrieves the bitness of a process by checking the Wow64Process flag.
    This function uses P/Invoke to call the Windows API function IsWow64Process.
  .NOTES
    Only works on Windows.
    Requires elevated privileges to check all processes.
  .LINK
    https://github.com/chadnpc/cliHelper.core/blob/main/Public/Runner/Get-ProcessBitness.ps1
  .LINK
    https://rkeithhill.wordpress.com/2014/04/28/how-to-determine-if-a-process-is-32-or-64-bit/
  .EXAMPLE
    Get-ProcessBitness 1234
    Get-ProcessBitness explorer
  #>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [int[]]$Ids
  )
  begin {
    $Signature = @{
      Namespace        = "Kernel32"
      Name             = "Bitness"
      Language         = "CSharp"
      MemberDefinition = @"
[DllImport("kernel32.dll", SetLastError = true, CallingConvention = CallingConvention.Winapi)]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool IsWow64Process(
	[In] System.IntPtr hProcess,
	[Out, MarshalAs(UnmanagedType.Bool)] out bool wow64Process);
"@
    }
    if (!("Kernel32.Bitness" -as [type])) {
      Add-Type @Signature
    }
  }

  process {
    Get-Process -Id $Ids | ForEach-Object -Process {
      $is32Bit = [int]0
      if ([Kernel32.Bitness]::IsWow64Process($_.Handle, [ref]$is32Bit)) {
        if ($is32Bit) {
          "$($_.Name) is 32-bit"
        } else {
          "$($_.Name) is 64-bit"
        }
      }
    }
  }
}