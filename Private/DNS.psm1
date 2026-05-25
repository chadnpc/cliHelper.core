
using module .\IPManagement.psm1

class DNS {
  static [void] GetDNSHostEntryAsync([string[]] $ComputerName) {
    $Computerlist = [System.Collections.ArrayList]::new()
    $Computerlist.AddRange($ComputerName)
    $Task = foreach ($Computer in $Computerlist) {
      if (([bool]($Computer -as [ipaddress]))) {
        [pscustomobject] @{
          Computername = $Computer
          Task         = [System.Net.Dns]::GetHostEntryAsync($Computer)
        }
      } else {
        [pscustomobject] @{
          Computername = $Computer
          Task         = [System.Net.Dns]::GetHostAddressesAsync($Computer)
        }
      }
    }
    try {
      $null = [System.Threading.Tasks.Task]::WaitAll($Task.Task)
    } catch { Write-Error -Message 'Error encountered' }
    $Task | ForEach-Object {
      $Result = if ($_.Task.IsFaulted) {
        $_.Task.Exception.InnerException.Message
      } else {
        if ($_.Task.Result.IPAddressToString) {
          $_.Task.Result.IPAddressToString
        } else {
          $_.Task.Result.HostName
        }
      }
      $Object = [pscustomobject] @{
        ComputerName = $_.Computername
        Result       = $Result
      }
      $Object.pstypenames.insert(0, 'Net.AsyncGetHostResult')
      $Object
    }
  }

  static [object] ResolveFQDN([string[]] $ComputerName, [bool] $IncludeInput) {
    $result = @()
    foreach ($curComputer in $ComputerName) {
      if ($curComputer -eq '.') { $curComputer = $env:COMPUTERNAME }
      $curComputer = $curComputer.ToLower()
      try {
        $FQDN = [System.Net.Dns]::GetHostEntry($curComputer).HostName
        $FQDN = $FQDN.ToLower()
      } catch {
        $FQDN = 'Not found'
      }
      if ($IncludeInput) {
        $result += [pscustomobject]@{ HostName = $curComputer; FQDN = $FQDN }
      } else {
        $result += $FQDN
      }
    }
    return $result
  }

  static [object] ResolveHostName([string[]] $Hostname, [bool] $IncludeInput) {
    $result = @()
    foreach ($curHost in $Hostname) {
      if ($curHost -eq '.') { $curHost = $env:computername }
      $curHost = $curHost.ToLower()
      try {
        $ipv4 = ([System.Net.Dns]::GetHostAddresses($curHost) | Where-Object { $_.AddressFamily -eq 'InterNetwork' }).IPAddressToString
        if ($ipv4 -eq '92.242.140.21') { $ipv4 = $false }
        if ([IPManagement]::TestIsValidIPv4(@($ipv4), $false)) {
          if ($IncludeInput) {
            $result += [pscustomobject]@{ Hostname = $curHost; IPv4 = $ipv4 }
          } else { $result += $ipv4 }
        } else {
          if ($IncludeInput) {
            $result += [pscustomobject]@{ Hostname = $curHost; IPv4 = $false }
          } else { $result += $false }
        }
      } catch {
        if ($IncludeInput) {
          $result += [pscustomobject]@{ Hostname = $curHost; IPv4 = $false }
        } else { $result += $false }
      }
    }
    return $result
  }
}


