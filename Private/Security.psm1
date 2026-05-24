
class Security {

  static [object] ClosePort([uint32[]]$Port, [string[]]$Protocol) {
    $result = @()
    $firewall        = New-Object -ComObject HNetCfg.FwMgr
    $firewallProfile = $firewall.LocalPolicy.CurrentProfile
    foreach ($p in $Port) {
      $toClose = $firewallProfile.GloballyOpenPorts | Where-Object { $_.Port -eq $p }
      foreach ($proto in $Protocol) {
        if ($proto -eq 'TCP')      { $firewallProfile.GloballyOpenPorts.Remove($toClose, 6) }
        elseif ($proto -eq 'UDP') { $firewallProfile.GloballyOpenPorts.Remove($toClose, 17) }
      }
      $result += [PSCustomObject]@{ Port = $p; Closed = $true }
    }
    return $result
  }

  static [object] GetNetworkCredential([System.Management.Automation.PSCredential]$Credential) {
    return $Credential.GetNetworkCredential()
  }

  static [object] GetSID([string]$Domain, [string]$Username, [string]$Email, [bool]$IncludeInput) {
    $result = $null
    if (![string]::IsNullOrEmpty($Domain) -and ![string]::IsNullOrEmpty($Username)) {
      $ADObj      = [Security.Principal.NTAccount]::new($Domain, $Username)
      $SID        = $ADObj.Translate([Security.Principal.SecurityIdentifier])
      $ReturnVal  = $SID.Value
      $result     = if ($IncludeInput) {
        [PSCustomObject]@{ Domain = $Domain.ToLower(); UserName = $Username.ToLower(); SID = $ReturnVal }
      } else { $ReturnVal }
    } elseif (![string]::IsNullOrEmpty($Email)) {
      $ADObj      = [Security.Principal.NTAccount]::new($Email)
      $SID        = $ADObj.Translate([Security.Principal.SecurityIdentifier])
      $ReturnVal  = $SID.Value
      $result     = if ($IncludeInput) { [PSCustomObject]@{ Email = $Email.ToLower(); SID = $ReturnVal } } else { $ReturnVal }
    }
    return $result
  }

  static [UInt32] ConvertToDecimalIP([System.Net.IPAddress]$IPAddress) {
    $i = 3; $DecimalIP = [UInt32]0
    $IPAddress.GetAddressBytes() | ForEach-Object { $DecimalIP += [UInt32]($_ * [Math]::Pow(256, $i)); $i-- }
    return $DecimalIP
  }

  static [string] ConvertToDottedDecimalIP([string]$IPAddress) {
    $result = $null
    if ($IPAddress -match "^([01]{8}\.){3}[01]{8}$") {
      $result = [String]::Join('.', ($IPAddress.Split('.') | ForEach-Object { [Convert]::ToUInt32($_, 2) }))
    } elseif ($IPAddress -match "^\d+$") {
      $val = [UInt32]$IPAddress
      $dotted = for ($i = 3; $i -gt -1; $i--) {
        $rem = $val % [Math]::Pow(256, $i)
        ($val - $rem) / [Math]::Pow(256, $i)
        $val = [UInt32]$rem
      }
      $result = [String]::Join('.', $dotted)
    } else {
      Write-Error "Cannot convert '$IPAddress' to dotted decimal IP"
    }
    return $result
  }

  static [PSCustomObject] GetNetworkAddress([System.Net.IPAddress]$IPAddress, [System.Net.IPAddress]$SubnetMask) {
    $decIP   = [Security]::ConvertToDecimalIP($IPAddress)
    $decMask = [Security]::ConvertToDecimalIP($SubnetMask)
    $netAddr = [Security]::ConvertToDottedDecimalIP(($decIP -band $decMask).ToString())
    return [PSCustomObject]@{ NetworkAddress = $netAddr }
  }

  static [string] ConvertToMask([int]$MaskLength) {
    [ValidateRange(0,32)][int]$MaskLength = $MaskLength
    return [Security]::ConvertToDottedDecimalIP([Convert]::ToUInt32(('1' * $MaskLength).PadRight(32, '0'), 2).ToString())
  }

  static [string[]] GetNetworkRange([string]$IP, [string]$Mask) {
    if ($IP.Contains('/')) {
      $parts = $IP.Split('/')
      $IP    = $parts[0]
      $Mask  = $parts[1]
    }
    if (!$Mask.Contains('.')) { $Mask = [Security]::ConvertToMask([int]$Mask) }
    $DecimalIP   = [Security]::ConvertToDecimalIP([System.Net.IPAddress]$IP)
    $DecimalMask = [Security]::ConvertToDecimalIP([System.Net.IPAddress]$Mask)
    $Network     = $DecimalIP -band $DecimalMask
    $Broadcast   = $DecimalIP -bor ((-bnot $DecimalMask) -band [UInt32]::MaxValue)
    $range = [System.Collections.Generic.List[string]]::new()
    for ($i = $Network + 1; $i -lt $Broadcast; $i++) {
      $range.Add([Security]::ConvertToDottedDecimalIP($i.ToString()))
    }
    return $range.ToArray()
  }

  static [bool] TestPing([string]$ComputerName) {
    try {
      $ping = [System.Net.NetworkInformation.Ping]::new()
      return ($ping.Send($ComputerName, 200).Status -ne 'TimedOut')
    } catch {
      return $false
    }
  }

  static [bool] TestWmi([string]$IpAddress) {
    try {
      $result = ([WMICLASS]"\\$IpAddress\Root\CIMV2:Win32_Process").Create("hostname")
      return ($result.ReturnValue -eq 0)
    } catch {
      return $false
    }
  }

  static [object] SendWolProxyRequest([string]$Computername, [string]$ConfigMgrSite, [string]$ConfigMgrSiteServer, [string]$WolCmdFilePath, [bool]$UsePsRemoting, [string]$KnownGoodWolProxyHostsFilePath) {
    if (Test-Connection -ComputerName $Computername -Quiet -Count 1) {
      Write-Verbose "The computer $Computername is already online"
      return $null
    }
    $LocalIPAddressNetworks = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'" |
      Where-Object { $_.IPAddress -and $_.IPSubnet } |
      ForEach-Object { [PSCustomObject]@{ LocalIPNetwork = ([Security]::GetNetworkAddress([Net.IPAddress]$_.IPAddress[0], [Net.IPAddress]$_.IPSubnet[0])).NetworkAddress } }

    $WolUdpPort = 9
    $WmiQuery = "SELECT DISTINCT * FROM SMS_R_System AS sys JOIN SMS_G_System_NETWORK_ADAPTER_CONFIGURATION AS net ON net.ResourceID = sys.ResourceID WHERE sys.Name = '$Computername' AND net.IPAddress IS NOT NULL"
    $WmiParams = @{ 'ComputerName' = $ConfigMgrSiteServer; 'Namespace' = "root\sms\site_$ConfigMgrSite"; 'Query' = $WmiQuery }
    try {
      $NetworkInfo = Get-WmiObject @WmiParams
      if (!$NetworkInfo) { throw "Computer '$Computername' could not be found in the SCCM database" }
      $OfflineComputerNetwork = $NetworkInfo | ForEach-Object {
        [PSCustomObject]@{
          IPAddress  = [string]([regex]'\b(?:\d{1,3}\.){3}\d{1,3}\b').Matches($_.net.IPAddress)
          SubnetMask = [string]([regex]'\b(?:\d{1,3}\.){3}\d{1,3}\b').Matches($_.net.IPSubnet)
          MACAddress = [string]($_.net.MACAddress -replace '[:\-\.]', '')
        }
      }
    } catch {
      Write-Error $_.Exception.Message
      return $null
    }
    foreach ($Network in $OfflineComputerNetwork) {
      $RemoteIpNetwork = [Security]::GetNetworkAddress([Net.IPAddress]$Network.IPAddress, [Net.IPAddress]$Network.SubnetMask)
      if ($LocalIPAddressNetworks.LocalIPNetwork -contains $RemoteIpNetwork.NetworkAddress) {
        & $WolCmdFilePath $Network.MacAddress $RemoteIpNetwork.NetworkAddress $Network.SubnetMask $WolUdpPort 2>&1 | Out-Null
      } else {
        $HostIps = [Security]::GetNetworkRange($Network.IPAddress, $Network.SubnetMask)
        $WolProxy = $null
        foreach ($Ip in $HostIps) {
          if ([Security]::TestPing($Ip) -and [Security]::TestWmi($Ip)) { $WolProxy = $Ip; break }
        }
        if (!$WolProxy) {
          Write-Warning "Unable to find a WOL proxy for '$Computername'"
        } else {
          Copy-Item $WolCmdFilePath "\\$WolProxy\c$" -Force
          $WolCmdString = "C:\$($WolCmdFilePath | Split-Path -Leaf) $($Network.MACAddress) $($RemoteIpNetwork.NetworkAddress) $($Network.SubnetMask) $WolUdpPort"
          $res = ([WMICLASS]"\\$WolProxy\Root\CIMV2:Win32_Process").Create($WolCmdString)
          if ($res) {
            while (Get-Process -Id $res.ProcessID -ComputerName $WolProxy -ErrorAction SilentlyContinue) { Start-Sleep 1 }
          }
          Remove-Item "\\$WolProxy\c$\$($WolCmdFilePath | Split-Path -Leaf)" -Force -ErrorAction SilentlyContinue
        }
      }
    }
    return $null
  }


  static [void] SetDynamicPort([string]$StartPort, [string]$EndPort) {
    $hc = Get-Command netsh -Type Application -ErrorAction Ignore
    if (!$hc) { Write-Warning 'netsh not found'; return }
    netsh int ipv4 set dynamicport tcp start=49152 num=16384 | Out-Null
    netsh int ipv4 set dynamicport udp start=49152 num=16384 | Out-Null
    netsh int ipv6 set dynamicport tcp start=49152 num=16384 | Out-Null
    netsh int ipv6 set dynamicport udp start=49152 num=16384 | Out-Null
    Write-Verbose "Dynamic port range set: start=$StartPort end=$EndPort"
  }

  static [void] SetTlsLevel([bool]$Tls12, [bool]$Revert) {
    if ($Tls12 -and !$Revert) {
      [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
      Write-Verbose "TLS 1.2 enabled"
    } elseif ($Revert) {
      [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::SystemDefault
      Write-Verbose "TLS settings reverted to system default"
    }
  }
}