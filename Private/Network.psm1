using namespace System.IO
using namespace System.Net
using namespace System.Text
using namespace System.Net.Http
using namespace System.Reflection
using namespace System.Diagnostics
using namespace System.Net.Sockets
using namespace System.Net.Security
using namespace System.Net.NetworkInformation
using namespace System.Runtime.InteropServices
using namespace System.Security.Authentication
using namespace System.Text.RegularExpressions

using module .\Config.psm1
using module .\Console.psm1
using module .\Models.psm1
using module .\Utilities.psm1
using module .\DllUtils.psm1

class HostsEntry {
  [int]$LineNumber
  [string]$IPAddress
  [bool]$IsValidIP
  [string]$Hostname
  [string]$Comment

  HostsEntry([int]$LineNumber, [string]$IPAddress, [string]$Hostname, [string]$Comment) {
    $this.LineNumber = $LineNumber
    $this.IPAddress = $IPAddress
    $this.Hostname = $Hostname
    $this.Comment = $Comment.Trim()
    $testIP = $null
    $this.IsValidIP = [Net.IPAddress]::TryParse($IPAddress, [ref]$testIP)
  }

  [string] ToString() {
    if ([string]::IsNullOrWhiteSpace($this.Comment)) {
      return "$($this.IPAddress) $($this.Hostname)"
    }
    return "$($this.IPAddress) $($this.Hostname) # $($this.Comment)"
  }
}


class HostsFile {
  static [string] $DefaultPath = (Join-Path $Env:SystemRoot 'System32\drivers\etc\hosts')
  [string] $Path
  [System.Collections.Generic.List[HostsEntry]] $Entries
  hidden [string[]] $RawLines

  HostsFile([string]$Path) {
    if (!(Test-Path $Path)) {
      throw "Hosts file does not exist: $Path"
    }
    $this.Path = $Path
    $this.Entries = [System.Collections.Generic.List[HostsEntry]]::new()
    $this.Load()
  }

  static [HostsFile] Create() {
    return [HostsFile]::new([HostsFile]::DefaultPath)
  }

  static [HostsFile] Create([string]$Path) {
    return [HostsFile]::new($Path)
  }

  hidden [void] Load() {
    $this.RawLines = Get-Content $this.Path -ErrorAction Stop
    $commentLine = '^\s*#'
    $hostLine = '^\s*(?<IPAddress>\S+)\s+(?<Hostname>\S+)(\s*|\s+#(?<Comment>.*))$'
    for ($i = 0; $i -lt $this.RawLines.Length; $i++) {
      $line = $this.RawLines[$i]
      if (!($line -match $commentLine) -and ($line -match $hostLine)) {
        $comment = ''
        if ($Matches['Comment']) { $comment = $Matches['Comment'] }
        $entry = [HostsEntry]::new($i, $Matches['IPAddress'], $Matches['Hostname'], $comment)
        $this.Entries.Add($entry)
      }
    }
  }

  [HostsEntry[]] GetEntries() { return $this.Entries.ToArray() }

  [HostsEntry] GetByHostname([string]$Hostname) {
    foreach ($entry in $this.Entries) {
      if ($entry.Hostname -eq $Hostname) { return $entry }
    }
    return $null
  }

  [HostsEntry[]] GetByIPAddress([string]$IPAddress) {
    $results = [System.Collections.Generic.List[HostsEntry]]::new()
    foreach ($entry in $this.Entries) {
      if ($entry.IPAddress -eq $IPAddress) { $results.Add($entry) }
    }
    return $results.ToArray()
  }

  [void] Add([string]$IPAddress, [string]$Hostname) { $this.Add($IPAddress, $Hostname, "") }

  [void] Add([string]$IPAddress, [string]$Hostname, [string]$Comment) {
    $existing = $this.GetByHostname($Hostname)
    $newEntry = [HostsEntry]::new(-1, $IPAddress, $Hostname, $Comment)
    if ($existing) {
      $this.RawLines[$existing.LineNumber] = $newEntry.ToString()
      $existing.IPAddress = $IPAddress
      $existing.Comment = $Comment
      $existing.IsValidIP = [Net.IPAddress]::TryParse($IPAddress, [ref]([ipaddress]::Any))
    } else {
      $this.RawLines += $newEntry.ToString()
      $newEntry.LineNumber = $this.RawLines.Length - 1
      $this.Entries.Add($newEntry)
    }
  }

  [void] RemoveByHostname([string]$Hostname) {
    $remainingLines = [System.Collections.Generic.List[string]]::new()
    $newEntries = [System.Collections.Generic.List[HostsEntry]]::new()
    $lineNumber = 0
    foreach ($entry in $this.Entries) {
      if ($entry.Hostname -ne $Hostname) {
        $remainingLines.Add($entry.ToString())
        $entry.LineNumber = $lineNumber
        $newEntries.Add($entry)
        $lineNumber++
      }
    }
    $this.RawLines = $remainingLines.ToArray()
    $this.Entries = $newEntries
  }

  [void] RemoveByIPAddress([string]$IPAddress) {
    $remainingLines = [System.Collections.Generic.List[string]]::new()
    $newEntries = [System.Collections.Generic.List[HostsEntry]]::new()
    $lineNumber = 0
    foreach ($entry in $this.Entries) {
      if ($entry.IPAddress -ne $IPAddress) {
        $remainingLines.Add($entry.ToString())
        $entry.LineNumber = $lineNumber
        $newEntries.Add($entry)
        $lineNumber++
      }
    }
    $this.RawLines = $remainingLines.ToArray()
    $this.Entries = $newEntries
  }

  [void] Save() { $this.RawLines | Out-File -Encoding ascii -FilePath $this.Path -ErrorAction Stop }
  [void] Show() { notepad $this.Path }
  [string] ToString() { return $this.Path }
}


class NetworkManager {
  [string] $HostName
  static [System.Net.IPAddress[]] $IPAddresses

  static [string] $caller

  NetworkManager([string]$HostName) {
    $this.HostName = $HostName
    $this::IPAddresses = [System.Net.Dns]::GetHostAddresses($HostName)
  }

  static [string] GetResponse([string]$URL) {
    [System.Net.HttpWebRequest]$Request = [System.Net.HttpWebRequest]::Create($URL)
    $Request.Method = "GET"
    $Request.Timeout = 10000
    [System.Net.HttpWebResponse]$Response = [System.Net.HttpWebResponse]$Request.GetResponse()
    if ($Response.StatusCode -eq [System.Net.HttpStatusCode]::OK) {
      [System.IO.Stream]$ReceiveStream = $Response.GetResponseStream()
      [System.IO.StreamReader]$ReadStream = [System.IO.StreamReader]::new($ReceiveStream)
      [string]$Content = $ReadStream.ReadToEnd()
      $ReadStream.Close()
      $Response.Close()
      return $Content
    } else {
      throw "The request failed with status code: $($Response.StatusCode)"
    }
  }

  static [void] BlockAllOutbound() {
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) {
      & sudo iptables -P OUTPUT DROP
    } else {
      netsh advfirewall set allprofiles firewallpolicy blockinbound, blockoutbound
    }
  }

  static [void] UnblockAllOutbound() {
    if ([System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)) {
      & sudo iptables -P OUTPUT ACCEPT
    } else {
      netsh advfirewall set allprofiles firewallpolicy blockinbound, allowoutbound
    }
  }

  static [void] UploadFile([string]$SourcePath, [string]$DestinationURL) {
    Invoke-RestMethod -Uri $DestinationURL -Method Post -InFile $SourcePath
  }

  static [bool] TestConnection([string]$HostName) {
    [ValidateNotNullOrEmpty()][string]$HostName = $HostName
    if (![bool]("System.Net.NetworkInformation.Ping" -as 'type')) { Add-Type -AssemblyName System.Net.NetworkInformation }
    $cs = $null; $cc = [NetworkManager]::caller
    $re = @{ true = @{ m = "Success"; c = "Green" }; false = @{ m = "Failed"; c = "Red" } }
    Write-Host "$cc Testing Connection ... " -ForegroundColor Blue -NoNewline
    try {
      [System.Net.NetworkInformation.PingReply]$PingReply = [System.Net.NetworkInformation.Ping]::new().Send($HostName)
      $cs = $PingReply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success
    } catch [System.Net.Sockets.SocketException], [System.Net.NetworkInformation.PingException] {
      $cs = $false
    } catch {
      $cs = $false
      Write-Error $_
    }
    $re = $re[$cs.ToString()]
    Write-Host $re.m -ForegroundColor $re.c
    return $cs
  }

  static [bool] IsIPv6AddressValid([string]$IP) {
    $IPv4Regex = '(((25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})\.){3}(25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))'
    $G = '[a-f\d]{1,4}'
    $Tail = @(":",
      "(:($G)?|$IPv4Regex)",
      ":($IPv4Regex|$G(:$G)?|)",
      "(:$IPv4Regex|:$G(:$IPv4Regex|(:$G){0,2})|:)",
      "((:$G){0,2}(:$IPv4Regex|(:$G){1,2})|:)",
      "((:$G){0,3}(:$IPv4Regex|(:$G){1,2})|:)",
      "((:$G){0,4}(:$IPv4Regex|(:$G){1,2})|:)")
    [string] $IPv6RegexString = $G
    $Tail | ForEach-Object { $IPv6RegexString = "${G}:($IPv6RegexString|$_)" }
    $IPv6RegexString = ":(:$G){0,5}((:$G){1,2}|:$IPv4Regex)|$IPv6RegexString"
    $IPv6RegexString = $IPv6RegexString -replace '\(' , '(?:'
    [regex] $IPv6Regex = $IPv6RegexString
    return ($IP -imatch "^$IPv6Regex$")
  }

  static [bool] IsMACAddressValid([string]$mac) {
    $RegEx = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})|([0-9A-Fa-f]{2}){6}$"
    return ($mac -match $RegEx)
  }

  static [bool] IsSubNetMaskValid([string]$IP) {
    $RegEx = "^(254|252|248|240|224|192|128).0.0.0$|^255.(254|252|248|240|224|192|128|0).0.0$|^255.255.(254|252|248|240|224|192|128|0).0$|^255.255.255.(255|254|252|248|240|224|192|128|0)$"
    return ($IP -match $RegEx)
  }

  static [bool] IsIPv4AddressValid([string]$IP) {
    $RegEx = "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
    return ($IP -match $RegEx)
  }
}


class NetworkDevice {
  [string]$IpAddress = ""
  [string]$Hostname = ""
  [string]$MacAddress = ""
  [string]$Vendor = ""
  [string]$DeviceType = "Unknown"
  [System.Collections.Generic.List[int]]$OpenPorts = [System.Collections.Generic.List[int]]::new()

  # Active fingerprint fields
  [System.Nullable[int]]$Ttl
  [string]$HttpTitle = ""
  [string]$HttpServer = ""
  [string]$SshBanner = ""
  [string]$TlsSubject = ""
  [string]$SmbOs = ""
  [string]$SnmpDescr = ""
  [string]$NetbiosName = ""
  [System.Collections.Generic.List[string]]$MdnsServices = [System.Collections.Generic.List[string]]::new()
  [string]$SsdpServer = ""

  [string] get_OpenPortsDisplay() {
    if ($this.OpenPorts.Count -gt 0) {
      return $this.OpenPorts -join ", "
    }
    return "-"
  }

  [uint32] get_IpSortKey() {
    $addr = [System.Net.IPAddress]::Any
    if ([System.Net.IPAddress]::TryParse($this.IpAddress, [ref]$addr)) {
      $bytes = $addr.GetAddressBytes()
      if ($bytes.Length -eq 4) {
        return [uint32]($bytes[0] -shl 24 -bor $bytes[1] -shl 16 -bor $bytes[2] -shl 8 -bor $bytes[3])
      }
    }
    return 0
  }
}

class DeviceOverrides {
  static [string]$FilePath = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'KillerScan', 'overrides.json')
  static [System.Collections.Generic.Dictionary[string, string]]$_overrides = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)

  static [void] Load() {
    try {
      if (!(Test-Path [DeviceOverrides]::FilePath)) { return }
      $json = Get-Content [DeviceOverrides]::FilePath -Raw
      $loaded = ConvertFrom-Json $json -AsHashtable
      if ($null -ne $loaded) {
        [DeviceOverrides]::_overrides = [System.Collections.Generic.Dictionary[string, string]]::new($loaded, [System.StringComparer]::OrdinalIgnoreCase)
      }
    } catch {
      $null
      # Ignore JSON load errors
    }
  }

  static [void] Save() {
    try {
      $dir = [System.IO.Path]::GetDirectoryName([DeviceOverrides]::FilePath)
      if (!(Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
      $json = [DeviceOverrides]::_overrides | ConvertTo-Json -Depth 1
      $json | Out-File -FilePath [DeviceOverrides]::FilePath -Encoding UTF8 -Force
    } catch {
      $null
      # Ignore file save errors
    }
  }

  static [void] Set([string]$mac, [string]$deviceType) {
    if ([string]::IsNullOrEmpty($mac)) { return }
    $key = $mac.ToUpperInvariant()
    if ($null -eq $deviceType) {
      $null = [DeviceOverrides]::_overrides.Remove($key)
    } else {
      [DeviceOverrides]::_overrides[$key] = $deviceType
    }
    [DeviceOverrides]::Save()
  }

  static [string] Get([string]$mac) {
    if ([string]::IsNullOrEmpty($mac)) { return $null }
    $val = $null
    if ([DeviceOverrides]::_overrides.TryGetValue($mac.ToUpperInvariant(), [ref]$val)) {
      return $val
    }
    return $null
  }

  static [bool] Has([string]$mac) {
    if ([string]::IsNullOrEmpty($mac)) { return $false }
    return [DeviceOverrides]::_overrides.ContainsKey($mac.ToUpperInvariant())
  }
}

class OuiLookup {
  static [System.Collections.Generic.Dictionary[string, string]] $OuiTable = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  static [bool] $_loaded = $false

  static [void] Load() {
    if ([OuiLookup]::_loaded) { return }
    $moduleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrEmpty($moduleDir)) { $moduleDir = "." }
    $csvPath = Join-Path $moduleDir "KillerScan\oui.csv"
    if (!(Test-Path $csvPath)) { return }

    try {
      $data = Import-Csv $csvPath
      foreach ($row in $data) {
        $oui = $row.Assignment
        $vendor = $row."Organization Name"
        if (![string]::IsNullOrEmpty($oui)) {
          [OuiLookup]::OuiTable[$oui] = $vendor
        }
      }
      [OuiLookup]::_loaded = $true
    } catch {
      $null
      # Ignore CSV load errors
    }
  }

  static [string] GetVendor([string]$macAddress) {
    if (![OuiLookup]::_loaded) { [OuiLookup]::Load() }
    if ([string]::IsNullOrEmpty($macAddress) -or $macAddress.Length -lt 8) {
      return ""
    }
    $prefix = $macAddress.Replace(":", "").Replace("-", "").Substring(0, 6).ToUpperInvariant()
    $vendor = ""
    if ([OuiLookup]::OuiTable.TryGetValue($prefix, [ref]$vendor)) {
      return $vendor
    }
    return ""
  }

  static [int] get_Count() { return [OuiLookup]::OuiTable.Count }
}

class NetworkScanner {
  static [int[]]$ProbePorts = @(22, 53, 80, 443, 445, 515, 631, 902, 2179, 3389, 8006, 8123, 5000, 5001, 9100, 161, 8080, 8443, 21, 23, 548, 5353, 1900, 62078)

  static [pscustomobject[]]$HostnameKeywords = @(
    [pscustomobject]@{Pattern = "lgwebos"; Type = "Smart TV" },
    [pscustomobject]@{Pattern = "webostv"; Type = "Smart TV" },
    [pscustomobject]@{Pattern = "lgtv"; Type = "Smart TV" },
    [pscustomobject]@{Pattern = "roku"; Type = "Smart TV" },
    [pscustomobject]@{Pattern = "firetv"; Type = "Smart TV" },
    [pscustomobject]@{Pattern = "fire-tv"; Type = "Smart TV" },
    [pscustomobject]@{Pattern = "appletv"; Type = "Apple TV" },
    [pscustomobject]@{Pattern = "apple-tv"; Type = "Apple TV" },
    [pscustomobject]@{Pattern = "chromecast"; Type = "Smart TV" },
    [pscustomobject]@{Pattern = "smarttv"; Type = "Smart TV" },
    [pscustomobject]@{Pattern = "tizen"; Type = "Smart TV" },
    [pscustomobject]@{Pattern = "wiim"; Type = "Media Streamer" },
    [pscustomobject]@{Pattern = "linkplay"; Type = "Media Streamer" },
    [pscustomobject]@{Pattern = "sonos"; Type = "Media Streamer" },
    [pscustomobject]@{Pattern = "heos"; Type = "Media Streamer" },
    [pscustomobject]@{Pattern = "homeassistant"; Type = "Home Assistant" },
    [pscustomobject]@{Pattern = "home-assistant"; Type = "Home Assistant" },
    [pscustomobject]@{Pattern = "pihole"; Type = "DNS Server" },
    [pscustomobject]@{Pattern = "pi-hole"; Type = "DNS Server" },
    [pscustomobject]@{Pattern = "proxmox"; Type = "Hypervisor" },
    [pscustomobject]@{Pattern = "esxi"; Type = "Hypervisor" },
    [pscustomobject]@{Pattern = "unifi"; Type = "Network" },
    [pscustomobject]@{Pattern = "ubnt"; Type = "Network" },
    [pscustomobject]@{Pattern = "synology"; Type = "NAS" },
    [pscustomobject]@{Pattern = "diskstation"; Type = "NAS" },
    [pscustomobject]@{Pattern = "freenas"; Type = "NAS" },
    [pscustomobject]@{Pattern = "truenas"; Type = "NAS" }
  )

  static [System.Collections.Generic.Dictionary[string, string]] $OuiBadMap = $null

  static [void] InitStatic() {
    if ($null -eq [NetworkScanner]::OuiBadMap) {
      [NetworkScanner]::OuiBadMap = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
      [NetworkScanner]::OuiBadMap["C4:F7:C1"] = "Linkplay"
      [NetworkScanner]::OuiBadMap["58:CF:79"] = "Linkplay"
    }
  }

  static [System.Collections.Generic.List[System.Net.IPAddress]] GetAddressesInSubnet([string]$cidr) {
    [NetworkScanner]::InitStatic()
    $parts = $cidr.Trim().Split('/')
    $ip = [System.Net.IPAddress]::Parse($parts[0])
    $prefixLen = if ($parts.Length -gt 1) { [int]::Parse($parts[1]) } else { 24 }

    $ipBytes = $ip.GetAddressBytes()
    if ($ipBytes.Length -ne 4) { return [System.Collections.Generic.List[System.Net.IPAddress]]::new() }

    $reverseBytes = [System.Net.IPAddress]::NetworkToHostOrder([System.BitConverter]::ToInt32($ipBytes, 0))
    $ipUint = [uint32]$reverseBytes

    $mask = if ($prefixLen -eq 0) { [uint32]0 } else { [uint32](0xFFFFFFFF -shl (32 - $prefixLen)) }
    $network = $ipUint -band $mask
    $broadcast = $network -bor (-bnot $mask)

    $addresses = [System.Collections.Generic.List[System.Net.IPAddress]]::new()
    for ($addr = $network + 1; $addr -lt $broadcast; $addr++) {
      $b = [System.BitConverter]::GetBytes([System.Net.IPAddress]::HostToNetworkOrder([int32]$addr))
      $addresses.Add([System.Net.IPAddress]::new($b))
    }
    return $addresses
  }

  static [string] GetMacAddress([System.Net.IPAddress]$addr) {
    $address = [string]::Empty
    try {
      $mac = New-Object byte[] 6
      $ipInt = [System.BitConverter]::ToUInt32($addr.GetAddressBytes(), 0)
      $result = [DllUtils]::SendARP($ipInt, 0, $mac, 6)
      if ($result -eq 0) {
        $macStr = ($mac | ForEach-Object { $_.ToString("X2") }) -join ":"
        if ($macStr -ne "00:00:00:00:00:00") {
          $address = $macStr
        }
      }
    } catch {
      throw "Mac resolution failed"
    }
    return $address
  }

  static [System.Collections.Generic.Dictionary[string, string]] GetArpCache() {
    $cache = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
      $output = arp -a
      foreach ($line in $output) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        $parts = $trimmed -split '\s+'
        if ($parts.Length -ge 2) {
          $ip = $parts[0]
          $mac = $parts[1].Replace('-', ':').ToUpperInvariant()
          $testIp = $null
          if ([System.Net.IPAddress]::TryParse($ip, [ref]$testIp) -and $mac.Length -eq 17 -and $mac.Contains(':')) {
            $cache[$ip] = $mac
          }
        }
      }
    } catch {
      throw "ARP command failed"
    }
    return $cache
  }

  static [string] ClassifyDevice([NetworkDevice]$device) {
    [NetworkScanner]::InitStatic()
    $manual = [DeviceOverrides]::Get($device.MacAddress)
    if ($null -ne $manual) { return $manual }

    $ports = $device.OpenPorts
    $_host = [string]$device.Hostname.ToLowerInvariant()
    $title = [string]$device.HttpTitle.ToLowerInvariant()
    $server = [string]$device.HttpServer.ToLowerInvariant()
    $tls = [string]$device.TlsSubject.ToLowerInvariant()
    $ssh = [string]$device.SshBanner.ToLowerInvariant()
    $snmp = [string]$device.SnmpDescr.ToLowerInvariant()
    $nbName = [string]$device.NetbiosName.ToLowerInvariant()

    foreach ($kw in [NetworkScanner]::HostnameKeywords) {
      if ($_host.Contains($kw.Pattern.ToLowerInvariant())) { return $kw.Type }
    }

    $vendor = $device.Vendor.ToLowerInvariant()
    if (![string]::IsNullOrEmpty($device.MacAddress) -and $device.MacAddress.Length -ge 8) {
      $prefix = $device.MacAddress.Substring(0, 8).ToUpperInvariant()
      $corr = $null
      if ([NetworkScanner]::OuiBadMap.TryGetValue($prefix, [ref]$corr)) {
        $vendor = $corr.ToLowerInvariant()
      }
    }

    $scores = @{}
    $AddScore = {
      param([string]$type, [int]$s)
      $scores[$type] = ($scores[$type] -as [int]) + $s
    }

    $hasWorkstationPorts = $ports.Contains(3389) -or $ports.Contains(445)

    if ($ports.Contains(8006)) { &$AddScore "Hypervisor" 15 }
    if ($title.Contains("proxmox")) { &$AddScore "Hypervisor" 15 }
    if ($tls.Contains("vmware") -or $title.Contains("vmware esxi")) { &$AddScore "Hypervisor" 15 }
    if ($ports.Contains(902) -and $ports.Contains(443) -and !$hasWorkstationPorts) { &$AddScore "Hypervisor" 10 }
    if ($ports.Contains(2179) -and ($ports.Contains(5985) -or $ports.Contains(5986)) -and !$hasWorkstationPorts) { &$AddScore "Hypervisor" 8 }
    if ($tls.Contains("xenserver") -or $title.Contains("xenserver")) { &$AddScore "Hypervisor" 15 }

    if ($ports.Contains(3389) -and $ports.Contains(445)) { &$AddScore "Windows" 6 }
    if ($server.Contains("microsoft-iis")) { &$AddScore "Windows" 6 }
    if (![string]::IsNullOrEmpty($nbName) -and $ports.Contains(445)) { &$AddScore "Windows" 4 }
    if ($device.Ttl -ge 120 -and $device.Ttl -le 128 -and $ports.Contains(445)) { &$AddScore "Windows" 3 }

    if ($ports.Contains(3389) -and $ports.Contains(445) -and ($ports.Contains(80) -or $ports.Contains(443) -or $ports.Contains(53))) { &$AddScore "Windows Server" 6 }
    if ($title.Contains("exchange") -or $server.Contains("exchange")) { &$AddScore "Windows Server" 10 }
    if ($snmp.Contains("windows server")) { &$AddScore "Windows Server" 15 }

    $sshIsWindows = $ssh.Contains("for_windows")
    if ($sshIsWindows) { &$AddScore "Windows" 15 }
    if (!$sshIsWindows -and ($ssh.StartsWith("ssh-2.0-openssh") -or $ssh.StartsWith("ssh-1.99-openssh"))) { &$AddScore "Linux/SSH" 8 }
    if ($device.Ttl -ge 60 -and $device.Ttl -le 64 -and $ports.Contains(22) -and !$sshIsWindows) { &$AddScore "Linux/SSH" 3 }

    $isNetworkVendor = $vendor -match "cisco|ubiquiti|aruba|ruckus|meraki|netgear|tp-link|fortinet|juniper|mikrotik|gl technologies|gl.inet|draytek|zyxel|linksys|sonicwall|watchguard"
    if ($isNetworkVendor) { &$AddScore "Network" 8 }
    if ($ssh -match "cisco|routeros|mikrotik") { &$AddScore "Network" 15 }
    if ($title -match "unifi|fortigate|sonicwall|pfsense|opnsense|mikrotik") { &$AddScore "Network" 15 }
    if ($snmp -match "cisco ios|juniper|fortigate") { &$AddScore "Network" 12 }

    if ($isNetworkVendor -and $ports.Contains(53)) { &$AddScore "Router" 10 }
    if ($isNetworkVendor -and $ports.Contains(161) -and !$ports.Contains(53)) { &$AddScore "Switch/AP" 8 }

    $isPrinterVendor = $vendor -match "canon|epson|brother|xerox|lexmark|ricoh|konica|kyocera"
    if ($ports.Contains(9100) -or $ports.Contains(515) -or $ports.Contains(631)) { &$AddScore "Printer" 8 }
    if ($isPrinterVendor -and ($ports.Contains(9100) -or $ports.Contains(515) -or $ports.Contains(631))) { &$AddScore "Printer" 10 }
    if ($isPrinterVendor -and $ports.Count -le 3) { &$AddScore "Printer" 6 }
    if ($vendor.Contains("hewlett packard") -and $ports.Contains(9100)) { &$AddScore "Printer" 12 }
    if ($snmp -match "laserjet|officejet|printer") { &$AddScore "Printer" 15 }
    if ($title -match "embedded web server|web image monitor") { &$AddScore "Printer" 10 }

    if ($vendor -match "synology|qnap|asustor|drobo|buffalo|terramaster") { &$AddScore "NAS" 12 }
    if ($title -match "diskstation|synology|dsm ") { &$AddScore "NAS" 15 }
    if ($title -match "qts|qnap|truenas|freenas") { &$AddScore "NAS" 15 }
    if ($ports.Contains(548)) { &$AddScore "NAS" 4 }

    $isApple = $vendor.Contains("apple")
    if ($isApple -and $ports.Contains(62078)) { &$AddScore "Apple Device" 12 }
    if ($isApple -and $ports.Count -le 2) { &$AddScore "Apple Device" 6 }
    foreach ($svc in $device.MdnsServices) {
      if ($svc -match "_airplay|_raop|_airport") { &$AddScore "Apple Device" 10; break }
    }

    $isMobileVendor = $vendor -match "samsung|oneplus|xiaomi|huawei|motorola|oppo|vivo|zte|lg electronics"
    if ($isMobileVendor -and $ports.Count -le 2) { &$AddScore "Mobile" 8 }

    if ($vendor -match "hikvision|dahua|axis|amcrest|reolink|foscam") { &$AddScore "Camera" 12 }
    if ($title -match "hikvision|dahua|camera|dvr|nvr|ipcam") { &$AddScore "Camera" 12 }
    if ($ports.Contains(554)) { &$AddScore "Camera" 4 }

    if ($vendor -match "espressif|tuya|sonoff|shelly|nest|ecobee|signify|lutron|wemo|wyze|aqara|linkplay|wiim") { &$AddScore "IoT" 10 }

    if ($ports.Contains(8123)) { &$AddScore "Home Assistant" 12 }
    if ($title.Contains("home assistant") -or $_host.Contains("homeassistant") -or $_host.Contains("home-assistant")) { &$AddScore "Home Assistant" 15 }

    if ($title -match "pi-hole|pihole|adguard") { &$AddScore "DNS Server" 15 }
    if ($ports.Contains(53) -and $ports.Contains(80) -and !$isNetworkVendor) { &$AddScore "DNS Server" 6 }

    if ($ports.Contains(80) -or $ports.Contains(443) -or $ports.Contains(8080)) { &$AddScore "Web Device" 2 }

    if ($scores.Count -gt 0) {
      $sorted = $scores.GetEnumerator() | Sort-Object Value -Descending
      $winner = $sorted[0]
      if ($winner.Value -ge 6) { return $winner.Key }
    }

    $localAdminMac = $false
    if (![string]::IsNullOrEmpty($device.MacAddress) -and $device.MacAddress.Length -ge 2) {
      $firstByteStr = $device.MacAddress.Substring(0, 2)
      try {
        $firstByte = [System.Convert]::ToByte($firstByteStr, 16)
        $localAdminMac = ($firstByte -band 0x02) -ne 0
      } catch {
        $null
      }
    }
    if ($localAdminMac -and $ports.Count -eq 0) { return "Mobile" }

    if ($ports.Contains(22)) { return "Linux/SSH" }
    if ($ports.Contains(445) -or $ports.Contains(3389)) { return "Windows" }
    if ($ports.Contains(80) -or $ports.Contains(443)) { return "Web Device" }
    if ($ports.Count -eq 0 -and ![string]::IsNullOrEmpty($device.MacAddress)) { return "IoT" }
    if ($ports.Count -eq 0) { return "Unknown" }
    return "Other"
  }

  static [void] ProbeHttp([NetworkDevice]$device, [System.Net.IPAddress]$addr) {
    $candidates = @(
      @{Port = 80; Https = $false }, @{Port = 8080; Https = $false }, @{Port = 5000; Https = $false }, @{Port = 8123; Https = $false },
      @{Port = 443; Https = $true }, @{Port = 8443; Https = $true }, @{Port = 8006; Https = $true }, @{Port = 5001; Https = $true }
    )

    $handler = [System.Net.Http.HttpClientHandler]::new()
    $handler.ServerCertificateCustomValidationCallback = { $true }
    $handler.AllowAutoRedirect = $true
    $handler.MaxAutomaticRedirections = 2
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [System.TimeSpan]::FromMilliseconds(1500)
    $client.DefaultRequestHeaders.UserAgent.ParseAdd("KillerScan/1.2")

    foreach ($c in $candidates) {
      if (!$device.OpenPorts.Contains($c.Port)) { continue }
      try {
        $scheme = if ($c.Https) { "https" } else { "http" }
        $url = "{0}://{1}:{2}/" -f $scheme, $addr.ToString(), $c.Port
        $resp = $client.GetAsync($url).GetAwaiter().GetResult()

        $serverVals = $null
        if ($resp.Headers.TryGetValues("Server", [ref]$serverVals)) {
          $device.HttpServer = ($serverVals -join ", ").Trim()
        }

        $body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if ($body -match '<title[^>]*>([^<]+)</title>') {
          $device.HttpTitle = [System.Net.WebUtility]::HtmlDecode($Matches[1]).Trim()
        }

        if (![string]::IsNullOrEmpty($device.HttpTitle) -or ![string]::IsNullOrEmpty($device.HttpServer)) { break }
      } catch {
        throw "HTTP probe failed for this candidate"
      }
    }
    $client.Dispose()
    $handler.Dispose()
  }

  static [void] ProbeSshBanner([NetworkDevice]$device, [System.Net.IPAddress]$addr) {
    try {
      $tcp = [System.Net.Sockets.TcpClient]::new()
      $connect = $tcp.ConnectAsync($addr, 22)
      if ($connect.Wait(1000) -and $tcp.Connected) {
        $stream = $tcp.GetStream()
        $stream.ReadTimeout = 1500
        $buf = New-Object byte[] 256
        $n = $stream.Read($buf, 0, $buf.Length)
        if ($n -gt 0) {
          $banner = [System.Text.Encoding]::ASCII.GetString($buf, 0, $n).Trim()
          if ($banner.StartsWith("SSH-")) {
            $nl = $banner.IndexOfAny(@("`r", "`n"))
            $device.SshBanner = if ($nl -gt 0) { $banner.Substring(0, $nl) } else { $banner }
          }
        }
      }
      $tcp.Dispose()
    } catch {
      throw "SSH banner probe failed"
    }
  }

  static [void] ProbeTlsCert([NetworkDevice]$device, [System.Net.IPAddress]$addr) {
    $tlsPorts = @(443, 8443, 8006, 902, 5001)
    foreach ($port in $tlsPorts) {
      if (!$device.OpenPorts.Contains($port) -and $port -ne 443) { continue }
      try {
        $tcp = [System.Net.Sockets.TcpClient]::new()
        $connect = $tcp.ConnectAsync($addr, $port)
        if ($connect.Wait(1500) -and $tcp.Connected) {
          $ssl = [System.Net.Security.SslStream]::new($tcp.GetStream(), $false, { $true })
          $auth = $ssl.AuthenticateAsClientAsync($addr.ToString())
          if ($auth.Wait(1500)) {
            if ($null -ne $ssl.RemoteCertificate) {
              $device.TlsSubject = $ssl.RemoteCertificate.Subject
              $tcp.Dispose()
              return
            }
          }
        }
        $tcp.Dispose()
      } catch {
        $null
      }
    }
  }

  static [void] ProbeNetbios([NetworkDevice]$device, [System.Net.IPAddress]$addr) {
    $query = @(
      0x00, 0x00, 0x00, 0x10, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x20,
      0x43, 0x4B, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41,
      0x00,
      0x00, 0x21,
      0x00, 0x01
    )
    try {
      $udp = [System.Net.Sockets.UdpClient]::new()
      $udp.Client.SendTimeout = 500
      $udp.Client.ReceiveTimeout = 800
      $ep = [System.Net.IPEndPoint]::new($addr, 137)
      $null = $udp.Send($query, $query.Length, $ep)

      $remoteEP = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, 0)
      $resp = $udp.Receive([ref]$remoteEP)
      if ($resp.Length -ge 57) {
        $numNames = $resp[56]
        for ($i = 0; $i -lt $numNames -and 57 + ($i * 18) + 18 -le $resp.Length; $i++) {
          $off = 57 + ($i * 18)
          $suffix = $resp[$off + 15]
          if ($suffix -eq 0x00 -or $suffix -eq 0x20) {
            $name = [System.Text.Encoding]::ASCII.GetString($resp, $off, 15).Trim()
            if (![string]::IsNullOrWhiteSpace($name) -and $name -notmatch '[\x01\x02]') {
              $device.NetbiosName = $name
              break
            }
          }
        }
      }
      $udp.Dispose()
    } catch {
      $null
    }
  }

  static [void] ProbeSnmp([NetworkDevice]$device, [System.Net.IPAddress]$addr) {
    $query = @(
      0x30, 0x29,
      0x02, 0x01, 0x00,
      0x04, 0x06, 0x70, 0x75, 0x62, 0x6C, 0x69, 0x63,
      0xA0, 0x1C,
      0x02, 0x04, 0x7F, 0x8B, 0x2C, 0x1D,
      0x02, 0x01, 0x00,
      0x02, 0x01, 0x00,
      0x30, 0x0E,
      0x30, 0x0C,
      0x06, 0x08, 0x2B, 0x06, 0x01, 0x02, 0x01, 0x01, 0x01, 0x00,
      0x05, 0x00
    )
    try {
      $udp = [System.Net.Sockets.UdpClient]::new()
      $udp.Client.SendTimeout = 500
      $udp.Client.ReceiveTimeout = 1000
      $ep = [System.Net.IPEndPoint]::new($addr, 161)
      $null = $udp.Send($query, $query.Length, $ep)

      $remoteEP = [System.Net.IPEndPoint]::new([System.Net.IPAddress]::Any, 0)
      $resp = $udp.Receive([ref]$remoteEP)
      if ($resp.Length -ge 30) {
        for ($i = $resp.Length - 2; $i -ge 0; $i--) {
          if ($resp[$i] -eq 0x04) {
            $len = $resp[$i + 1]
            if ($len -ge 5 -and $i + 2 + $len -le $resp.Length) {
              $s = [System.Text.Encoding]::UTF8.GetString($resp, $i + 2, $len)
              if ($s -ne "public" -and $s -notmatch '[\x00-\x1F]') {
                $device.SnmpDescr = $s.Trim()
                break
              }
            }
          }
        }
      }
      $udp.Dispose()
    } catch {
      $null
    }
  }

  static [NetworkDevice] ProbeHost([System.Net.IPAddress]$addr, [string]$cachedMac) {
    $device = [NetworkDevice]::new()
    $device.IpAddress = $addr.ToString()
    $device.MacAddress = $cachedMac

    try {
      $entry = [System.Net.Dns]::GetHostEntry($addr)
      $device.Hostname = $entry.HostName
    } catch {
      $null
    }

    try {
      $ping = [System.Net.NetworkInformation.Ping]::new()
      $reply = $ping.Send($addr, 400)
      if ($reply.Status -eq 'Success' -and $null -ne $reply.Options) {
        $device.Ttl = $reply.Options.Ttl
      }
    } catch {
      $null
    }

    [int[]]$portsFound = [NetworkScanner]::ProbePorts | ForEach-Object -Parallel {
      $tcp = [System.Net.Sockets.TcpClient]::new()
      try {
        $c = $tcp.ConnectAsync($using:addr, $_)
        if ($c.Wait(200) -and $tcp.Connected) { $_ }
      } catch {
        $null
      }
      $tcp.Dispose()
    } -ThrottleLimit 24
    if ($null -ne $portsFound) {
      foreach ($p in $portsFound) { $device.OpenPorts.Add($p) }
    }

    if (![string]::IsNullOrEmpty($device.MacAddress)) {
      $device.Vendor = [OuiLookup]::GetVendor($device.MacAddress)
    }

    if ($device.OpenPorts.Count -gt 0) {
      if ($device.OpenPorts | Where-Object { $_ -match '^(80|443|8006|8080|8443|5000|5001|8123)$' }) { [NetworkScanner]::ProbeHttp($device, $addr) }
      if ($device.OpenPorts -contains 22) { [NetworkScanner]::ProbeSshBanner($device, $addr) }
      if ($device.OpenPorts | Where-Object { $_ -match '^(443|8443|8006|902)$' }) { [NetworkScanner]::ProbeTlsCert($device, $addr) }
    }
    [NetworkScanner]::ProbeNetbios($device, $addr)
    [NetworkScanner]::ProbeSnmp($device, $addr)

    $device.DeviceType = [NetworkScanner]::ClassifyDevice($device)
    return $device
  }

  static [NetworkDevice[]] ScanSubnet([string]$cidr, [bool]$fullScan = $true) {
    [NetworkScanner]::InitStatic()
    $addresses = [NetworkScanner]::GetAddressesInSubnet($cidr)
    $discoveredHosts = @{}

    Write-Host "Discovering hosts on $cidr..." -ForegroundColor Blue

    $arpCache = [NetworkScanner]::GetArpCache()
    foreach ($addr in $addresses) {
      $ipStr = $addr.ToString()
      if ($arpCache.ContainsKey($ipStr)) { $discoveredHosts[$ipStr] = $arpCache[$ipStr] }
    }

    $aliveIps = $addresses | ForEach-Object -Parallel {
      $p = [System.Net.NetworkInformation.Ping]::new()
      try {
        $r = $p.Send($_.ToString(), 500)
        if ($r.Status -eq 'Success') { $_.ToString() }
      } catch {
        $null
      }
    } -ThrottleLimit 100

    if ($null -ne $aliveIps) {
      foreach ($ip in $aliveIps) {
        if (!$discoveredHosts.ContainsKey($ip)) { $discoveredHosts[$ip] = "" }
      }
    }

    Write-Host "Resolving $($discoveredHosts.Count) MAC addresses..." -ForegroundColor Blue
    $results = [System.Collections.Generic.List[NetworkDevice]]::new()

    $hostsToProbe = foreach ($key in $discoveredHosts.Keys) {
      [pscustomobject]@{IP = $key; Mac = $discoveredHosts[$key] }
    }

    if ($fullScan) {
      Write-Host "Probing $($hostsToProbe.Count) alive hosts..." -ForegroundColor Blue
      $resultsArr = $hostsToProbe | ForEach-Object -Parallel {
        $addr = [System.Net.IPAddress]::Parse($_.IP)
        $mac = $_.Mac
        if ([string]::IsNullOrEmpty($mac)) { $mac = [NetworkScanner]::GetMacAddress($addr) }
        return [NetworkScanner]::ProbeHost($addr, $mac)
      } -ThrottleLimit 10
      if ($null -ne $resultsArr) { $results.AddRange($resultsArr) }
    } else {
      foreach ($h in $hostsToProbe) {
        $addr = [System.Net.IPAddress]::Parse($h.IP)
        $mac = $h.Mac
        if ([string]::IsNullOrEmpty($mac)) { $mac = [NetworkScanner]::GetMacAddress($addr) }
        $dev = [NetworkDevice]::new()
        $dev.IpAddress = $h.IP
        $dev.MacAddress = $mac
        try {
          $entry = [System.Net.Dns]::GetHostEntry($addr)
          $dev.Hostname = $entry.HostName
        } catch {
          throw "Hostname resolution failed"
        }
        if (![string]::IsNullOrEmpty($mac)) { $dev.Vendor = [OuiLookup]::GetVendor($mac) }
        $dev.DeviceType = [NetworkScanner]::ClassifyDevice($dev)
        $results.Add($dev)
      }
    }

    return $results.ToArray() | Sort-Object { $_.get_IpSortKey() }
  }
}