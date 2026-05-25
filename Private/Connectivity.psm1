using namespace System
using namespace System.Net
using namespace System.Net.NetworkInformation
using namespace System.Net.Sockets

using module .\Models.psm1
using module .\DNS.psm1
using module .\IPManagement.psm1


class AsyncPingResult {
  [string]$Result
  [string]$IPAddress
  [int]$ResponseTime
  [int]$BufferSize
  hidden [string]$ComputerName
  hidden [bool]$DontFragment
  hidden [string]$Source
  hidden $TimeToLive
  hidden $Timeout
}

class Connectivity {
  static [object] ConnectRemoteDesktop([string[]]$ComputerName, [System.Management.Automation.PSCredential]$Credential, [bool]$Admin, [bool]$MultiMon, [bool]$FullScreen, [bool]$Public, [int]$Width, [int]$Height, [bool]$Wait) {
    [string]$MstscArguments = -join $(
      switch ($true) {
        { $Admin } { '/admin ' }
        { $MultiMon } { '/multimon ' }
        { $FullScreen } { '/f ' }
        { $Public } { '/public ' }
        { $Width } { "/w:$Width " }
        { $Height } { "/h:$Height " }
      }
    )
    foreach ($Computer in $ComputerName) {
      $ProcessInfo = [System.Diagnostics.ProcessStartInfo]::new()
      $Process = [System.Diagnostics.Process]::new()
      $ComputerCmdkey = if ($Computer.Contains(':')) { ($Computer -split ':')[0] } else { $Computer }
      # Store credential via cmdkey
      $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
      $plainPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
      & cmdkey.exe /generic:"TERMSRV/$ComputerCmdkey" /user:$Credential.UserName /pass:$plainPwd | Out-Null
      [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
      $ProcessInfo.FileName = "$Env:SystemRoot\system32\mstsc.exe"
      $ProcessInfo.Arguments = "$MstscArguments /v $Computer"
      $ProcessInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
      $Process.StartInfo = $ProcessInfo
      [void]$Process.Start()
      if ($Wait) { $null = $Process.WaitForExit() }
    }
    return $null
  }


  static [PSCustomObject] GetPSSessionInfo() {
    $pid_val = [System.Diagnostics.Process]::GetCurrentProcess().Id
    $proc = Get-Process -Id $pid_val
    $cmd = $null
    $parent = $null
    $psVT = (Get-Variable PSVersionTable -ValueOnly -ErrorAction SilentlyContinue)
    $psEd = if ($psVT) { $psVT.PSEdition } else { 'Core' }
    if ($psEd -eq 'Desktop') {
      $cim = Get-CimInstance -ClassName Win32_process -Filter "processID = $($proc.Id)" -Property CommandLine, ParentProcessID
      $cmd = $cim.CommandLine
      $parent = Get-Process -Id $cim.ParentProcessId -ErrorAction SilentlyContinue
    } else {
      $cmd = $proc.CommandLine
      $parent = $proc.Parent
    }
    $psver = (Get-Variable PSVersionTable -ValueOnly -ErrorAction SilentlyContinue).PSVersion
    $info = [PSCustomObject]@{
      PSTypeName = 'PSSessionInfo'
      ProcessID  = $pid_val
      Command    = $cmd
      Host       = (Get-Variable Host -ValueOnly -ErrorAction SilentlyContinue).Name
      Started    = $proc.StartTime
      PSVersion  = $psver
      Elevated   = $false
      Parent     = $parent
    }
    Update-TypeData -TypeName PSSessionInfo -MemberType ScriptProperty -MemberName Runtime -Value { (Get-Date) - $this.Started } -Force
    Update-TypeData -TypeName PSSessionInfo -MemberType ScriptProperty -MemberName Memory -Value { (Get-Process -Id $this.ProcessID).WorkingSet / 1MB -as [int32] } -Force
    return $info
  }


  static [object] InvokeDig([string]$Name, [string]$Type, [string]$Server) {
    if (![string]::IsNullOrWhiteSpace($Server)) {
      $r = Resolve-DnsName -Name $Name -Type $Type -Server $Server | Format-Table -AutoSize | Out-String
    } else {
      $r = Resolve-DnsName -Name $Name -Type $Type -ErrorAction SilentlyContinue | Format-Table -AutoSize | Out-String
    }
    if (!$r) { Write-Warning "Unable to resolve [$Name] :(" }
    return $r
  }

  static [object] InvokePing([string]$Name, [int]$Count, [bool]$IPv6) {
    if ($IPv6) {
      $r = & ping.exe $Name -n $Count -6 -a
    } else {
      $r = & ping.exe $Name -n $Count -4 -a
    }
    return ($r -join "`n")
  }

  static [object] SendPingAsync([string[]]$ips) {
    $t = $ips | ForEach-Object { ([Net.NetworkInformation.Ping]::new()).SendPingAsync($_, 250) }
    [Threading.Tasks.Task]::WaitAll($t)
    return $t.Result
  }


  static [void] SendTCP([string]$TargetIP, [int]$TargetPort, [string]$Message) {
    try {
      if ([string]::IsNullOrEmpty($TargetIP)) { $TargetIP = Read-Host 'Enter target IP address' }
      if ($TargetPort -eq 0) { $TargetPort = [int](Read-Host 'Enter target port') }
      if ([string]::IsNullOrEmpty($Message)) { $Message = Read-Host 'Enter message to send' }

      $IP = [Dns]::GetHostAddresses($TargetIP)
      $Address = [IPAddress]::Parse($IP[0].ToString())
      $Socket = [TcpClient]::new($Address, $TargetPort)
      $Stream = $Socket.GetStream()
      $Writer = [System.IO.StreamWriter]::new($Stream)
      $Writer.WriteLine($Message)
      $Writer.Flush()
      $Stream.Close()
      $Socket.Close()
      Write-Host "Done." -ForegroundColor Green
    } catch {
      Write-Verbose "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
    }
  }

  static [void] SendUDP([string]$TargetIP, [int]$TargetPort, [string]$Message) {
    try {
      if ([string]::IsNullOrEmpty($TargetIP)) { $TargetIP = Read-Host 'Enter target IP address' }
      if ($TargetPort -eq 0) { $TargetPort = [int](Read-Host 'Enter target port') }
      if ([string]::IsNullOrEmpty($Message)) { $Message = Read-Host 'Enter message to send' }

      $IP = [Dns]::GetHostAddresses($TargetIP)
      $Address = [IPAddress]::Parse($IP[0].ToString())
      $EndPoints = [System.Net.IPEndPoint]::new($Address, $TargetPort)
      $Socket = [UdpClient]::new()
      $EncodedText = [Text.Encoding]::ASCII.GetBytes($Message)
      [void]$Socket.Send($EncodedText, $EncodedText.Length, $EndPoints)
      $Socket.Close()
      Write-Host "Done." -ForegroundColor Green
    } catch {
      Write-Verbose "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
    }
  }

  static [object[]] StartCimSession([string[]]$ComputerName, [System.Management.Automation.PSCredential]$Credential) {
    $Opt = New-CimSessionOption -Protocol Dcom
    $result = @()
    $SessionParams = @{ ErrorAction = 'Stop' }
    if ($null -ne $Credential) { $SessionParams.Credential = $Credential }
    foreach ($Computer in $ComputerName) {
      $SessionParams.ComputerName = $Computer
      if ((Test-WSMan -ComputerName $Computer -ErrorAction SilentlyContinue).productversion -match 'Stack: ([3-9]|[1-9][0-9]+)\.[0-9]+') {
        try {
          Write-Verbose "Attempting to connect to $Computer using the WSMAN protocol."
          $result += New-CimSession @SessionParams
        } catch {
          Write-Warning "Unable to connect to $Computer using the WSMAN protocol. Verify your credentials and try again."
        }
      } else {
        $SessionParams.SessionOption = $Opt
        try {
          Write-Verbose "Attempting to connect to $Computer using the DCOM protocol."
          $result += New-CimSession @SessionParams
        } catch {
          Write-Warning "Unable to connect to $Computer using the WSMAN or DCOM protocol. Verify $Computer is online and try again."
        }
        $SessionParams.Remove('SessionOption')
      }
    }
    return $result
  }


  static [object] TestConnectionAsync([string[]]$ComputerName, [int]$Timeout, [int]$TimeToLive, [int]$BufferSize, [bool]$IncludeSource, [bool]$Full) {
    $result = @()
    $Source = if ($IncludeSource) { $Env:COMPUTERNAME } else { $null }
    $Buffer = [System.Collections.ArrayList]::new()
    1..$BufferSize | ForEach-Object { $null = $Buffer.Add(([byte][char]'A')) }
    $PingOptions = [PingOptions]::new()
    $PingOptions.Ttl = $TimeToLive
    $DontFragment = $BufferSize -le 1500
    $PingOptions.DontFragment = $DontFragment

    $Task = foreach ($Computer in $ComputerName) {
      [pscustomobject]@{
        ComputerName = $Computer
        Task         = [Ping]::new().SendPingAsync($Computer, $Timeout, $Buffer, $PingOptions)
      }
    }
    try {
      [void][Threading.Tasks.Task]::WaitAll($Task.Task)
    } catch {
      Write-Error -Message "Error checking connections: $($_.Exception.Message)"
    }
    $Task | ForEach-Object {
      $r = [AsyncPingResult]::new()
      $r.ComputerName = $_.ComputerName
      $r.BufferSize = $BufferSize
      $r.Timeout = $Timeout
      $r.TimeToLive = $TimeToLive
      $r.DontFragment = $DontFragment
      if ($IncludeSource) { $r.Source = $Source }
      if ($_.Task.IsFaulted) {
        $r.Result = $_.Task.Exception.InnerException.InnerException.Message
        $r.IPAddress = $null
        $r.ResponseTime = 0
      } else {
        $r.Result = $_.Task.Result.Status
        $r.IPAddress = $_.Task.Result.Address.ToString()
        $r.ResponseTime = $_.Task.Result.RoundtripTime
      }
      $result += $r
    }
    return $result
  }


  static [void] TestDns([string[]]$InterfaceAlias, [int]$ThrottleLimit) {
    try {
      $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
      $PathToRepo = [IO.Path]::Combine((Get-Variable PSScriptRoot -ValueOnly), '..')
      $Table = Import-Csv "$PathToRepo/Data/domain-names.csv"
      foreach ($Row in $Table) {
        Write-Progress "Resolving $($Row.Domain) ..."
        $isLin = (Get-Variable IsLinux -ValueOnly -ErrorAction SilentlyContinue) -eq $true
        if ($isLin) {
          $null = & nslookup $Row.Domain
        } else {
          $null = Resolve-DnsName $Row.Domain -ErrorAction SilentlyContinue
        }
      }
      $Count = $Table.Count
      [int]$Elapsed = $StopWatch.Elapsed.TotalSeconds
      $Average = [math]::round($Count / [math]::Max($Elapsed, 1), 1)
      Write-Verbose "Resolved $Count domains. Average: $Average domains/sec"
    } catch {
      Write-Verbose "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
    }
  }


  static [object] TestNetwork([string[]]$Subnet) {
    $result = $null
    foreach ($curSubnet in $Subnet) {
      $net = [IPManagement]::GetIpRange($curSubnet)
      $result = [Connectivity]::TestConnectionAsync($net, 5000, 64, 32, $false, $false) |
        Select-Object -Property @{Name = 'IpAddress'; Expr = { $_.ComputerName } }, @{Name = 'ComputerName'; Expr = { $null } }, Result
      $Name = [DNS]::GetDNSHostEntryAsync($net)
      foreach ($curResult in $result) {
        $tmp = $Name | Where-Object { $_.ComputerName -eq $curResult.IpAddress }
        if ($tmp) {
          $curResult.ComputerName = if ($tmp.Result -eq 'No such host is known') { 'UNKNOWN' } else { $tmp.Result.ToLower() }
        }
        if ($curResult.Result -ne 'Success') { $curResult.Result = 'TimeOut' }
      }
      $result = $result | Where-Object { !($_.ComputerName -eq 'UNKNOWN' -and $_.Result -eq 'TimeOut') }
    }
    return $result
  }


  static [object] TestNetworkConnection([string]$ComputerName, [bool]$TraceRoute, [int]$Hops, [string]$CommonTCPPort, [int]$Port, [bool]$DiagnoseRouting, [string]$ConstrainSourceAddress, [uint32]$ConstrainInterface, [string]$InformationLevel, [bool]$Describe) {
    $result = $null
    if ($DiagnoseRouting) {
      $Return = [NetRouteDiagnostics]::new()
      $Return.ComputerName = $ComputerName
      if (![string]::IsNullOrEmpty($ConstrainSourceAddress)) { $Return.ConstrainSourceAddress = $ConstrainSourceAddress }
      $Return.ConstrainInterfaceIndex = $ConstrainInterface
      $Return.Detailed = ($InformationLevel -eq 'Detailed')
      if ($Return.Detailed -and (!([Connectivity]::CheckIfAdmin()))) {
        Write-Warning "'-InformationLevel Detailed' requires elevation (Run as administrator)."
        $Return.Detailed = $false
      }
      [Connectivity]::DiagnoseRouteSelection($Return)
      $result = $Return
    } else {
      $Return = [TestNetConnectionResult]::new()
      $Return.ComputerName = $ComputerName
      $Return.Detailed = ($InformationLevel -eq 'Detailed')
      $Return.ResolvedAddresses = [Connectivity]::ResolveTargetName($ComputerName)
      if ($null -eq $Return.ResolvedAddresses) {
        if ($InformationLevel -eq 'Quiet') { return $false }
        $Return.NameResolutionSucceeded = $false
        return $Return
      }
      $Return.RemoteAddress = $Return.ResolvedAddresses[0]
      $Return.NameResolutionSucceeded = $true

      $AttemptTcpTest = ![string]::IsNullOrEmpty($CommonTCPPort) -or $Port -gt 0
      if ($AttemptTcpTest) {
        $Return.TcpTestSucceeded = $false
        switch ($CommonTCPPort) {
          '' { $Return.RemotePort = $Port }
          'HTTP' { $Return.RemotePort = 80 }
          'RDP' { $Return.RemotePort = 3389 }
          'SMB' { $Return.RemotePort = 445 }
          'WINRM' { $Return.RemotePort = 5985 }
        }
        $Iter = 0
        while (($Iter -lt $Return.ResolvedAddresses.Count) -and (!$Return.TcpTestSucceeded)) {
          $Return.TcpTestSucceeded = [Connectivity]::TestTCP($Return.ResolvedAddresses[$Iter], $Return.RemotePort)
          if (!$Return.TcpTestSucceeded) { Write-Warning "TCP connect to ($($Return.ResolvedAddresses[$Iter]) : $($Return.RemotePort)) failed" }
          $Iter++
        }
        if ($Return.TcpTestSucceeded) { $Return.RemoteAddress = $Return.ResolvedAddresses[$Iter - 1] }
        if ($InformationLevel -eq 'Quiet') { return $Return.TcpTestSucceeded }
      }

      $AttemptPingTest = (!$AttemptTcpTest) -or (!$Return.TcpTestSucceeded)
      if ($AttemptPingTest) {
        $Return.PingSucceeded = $false
        $Iter = 0
        while (($Iter -lt $Return.ResolvedAddresses.Count) -and (!$Return.PingSucceeded)) {
          $Return.PingReplyDetails = [Connectivity]::PingTest($Return.ResolvedAddresses[$Iter])
          if ($null -ne $Return.PingReplyDetails) {
            $Return.PingSucceeded = ($Return.PingReplyDetails.Status -eq [IPStatus]::Success)
          }
          if (!$Return.PingSucceeded) {
            $WarningString = "Ping to $($Return.ResolvedAddresses[$Iter]) failed"
            if ($null -ne $Return.PingReplyDetails) { $WarningString += " with status: $($Return.PingReplyDetails.Status)" }
            Write-Warning $WarningString
          }
          $Iter++
        }
        if ($Return.PingSucceeded) { $Return.RemoteAddress = $Return.ResolvedAddresses[$Iter - 1] }
        if ($InformationLevel -eq 'Quiet') { return $Return.PingSucceeded }
      }

      if ($TraceRoute) { $Return.TraceRoute = [Connectivity]::TraceRoute($Return.RemoteAddress, $Hops) }
      $Return = [Connectivity]::ResolveDNSDetails($Return, $ComputerName)
      $Return = [Connectivity]::ResolveNetworkSecurityDetails($Return)
      $Return = [Connectivity]::ResolveRoutingandAdapterWMIObjects($Return)
      $result = $Return
    }
    return $result
  }


  static [bool] CheckIfAdmin() {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pri = [Security.Principal.WindowsPrincipal]::new($id)
    return $pri.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  }

  static [object] ResolveTargetName([string]$TargetName) {
    $Addresses = $null
    try {
      $Addresses = [Dns]::GetHostAddressesAsync($TargetName).GetAwaiter().GetResult()
    } catch {
      Write-Debug "Name resolution of $TargetName threw exception: $($_.Exception.Message)"
    }
    if ($null -eq $Addresses) { Write-Warning "Name resolution of $TargetName failed" }
    return $Addresses
  }

  static [object] PingTest([object]$TargetIPAddress) {
    $Ping = [Ping]::new()
    $PingReplyDetails = $null
    Write-Progress -Activity "Connectivity :: PingTest" -Status "Waiting for echo reply from $TargetIPAddress" -SecondsRemaining -1 -PercentComplete -1
    try {
      $PingReplyDetails = $Ping.SendPingAsync($TargetIPAddress).GetAwaiter().GetResult()
    } catch {
      Write-Debug "Ping to $TargetIPAddress threw exception: $($_.Exception.Message)"
    } finally {
      $Ping.Dispose()
    }
    return $PingReplyDetails
  }

  static [object] TraceRoute([object]$TargetIPAddress, [object]$Hops) {
    $Ping = [Ping]::new()
    $PingOptions = [PingOptions]::new()
    $PingOptions.Ttl = 1
    [Byte[]]$DataBuffer = @(0) * 10
    $ReturnTrace = @()
    $PingReplyDetails = $null
    do {
      try {
        $CurrentHop = [int]$PingOptions.Ttl
        Write-Progress -CurrentOperation "TTL = $CurrentHop" -Status "ICMP Echo Request (Max TTL = $Hops)" -Activity "TraceRoute" -PercentComplete -1 -SecondsRemaining -1
        $PingReplyDetails = $Ping.SendPingAsync($TargetIPAddress, 4000, $DataBuffer, $PingOptions).GetAwaiter().GetResult()
        $ReturnTrace += if ($null -eq $PingReplyDetails.Address) { $PingReplyDetails.Status.ToString() } else { $PingReplyDetails.Address.IPAddressToString }
      } catch {
        Write-Debug "Ping to $TargetIPAddress threw exception: $($_.Exception.Message)"
        $ReturnTrace += "..."
      }
      $PingOptions.Ttl++
    } while (($PingReplyDetails.Status -ne 'Success') -and ($PingOptions.Ttl -le $Hops))
    if ($ReturnTrace[-1] -ne $TargetIPAddress) {
      Write-Warning "Trace route to destination $TargetIPAddress did not complete. Trace terminated :: $($ReturnTrace[-1])"
    }
    $Ping.Dispose()
    return $ReturnTrace
  }

  static [object] TestTCP([object]$TargetIPAddress, [object]$TargetPort) {
    Write-Progress -Activity "Connectivity :: TestTCP $TargetIPAddress`:$TargetPort" -Status "Attempting TCP connect" -SecondsRemaining -1 -PercentComplete -1
    $Success = $false
    $TCPClient = [TcpClient]::new($TargetIPAddress.AddressFamily)
    try {
      $null = $TCPClient.ConnectAsync($TargetIPAddress, $TargetPort).GetAwaiter().GetResult()
      $Success = $TCPClient.Connected
    } catch {
      Write-Debug "TCP connect to ($TargetIPAddress : $TargetPort) threw exception: $($_.Exception.Message)"
    } finally {
      $TCPClient.Dispose()
    }
    return $Success
  }

  static [object] ResolveRoutingandAdapterWMIObjects([object]$TestNetConnectionResult) {
    try {
      $TestNetConnectionResult.SourceAddress, $TestNetConnectionResult.NetRoute = Find-NetRoute -RemoteIPAddress $TestNetConnectionResult.RemoteAddress -ErrorAction SilentlyContinue
      $TestNetConnectionResult.NetAdapter = $TestNetConnectionResult.NetRoute | Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue
      $TestNetConnectionResult.InterfaceAlias = $TestNetConnectionResult.NetRoute.InterfaceAlias
      $TestNetConnectionResult.InterfaceIndex = $TestNetConnectionResult.NetRoute.InterfaceIndex
      $TestNetConnectionResult.InterfaceDescription = $TestNetConnectionResult.NetAdapter.InterfaceDescription
    } catch {
      Write-Debug "ResolveRoutingandAdapterWMIObjects threw exception: $($_.Exception.Message)"
    }
    return $TestNetConnectionResult
  }

  static [object] ResolveDNSDetails([object]$TestNetConnectionResult, [string]$ComputerName) {
    $TestNetConnectionResult.DNSOnlyRecords = @(Resolve-DnsName $ComputerName -DnsOnly -NoHostsFile -Type A_AAAA -ErrorAction SilentlyContinue | Where-Object { $_.QueryType -in 'A', 'AAAA', 'PTR' })
    $TestNetConnectionResult.LLMNRNetbiosRecords = @(Resolve-DnsName $ComputerName -LlmnrNetbiosOnly -NoHostsFile -ErrorAction SilentlyContinue | Where-Object { $_.QueryType -in 'A', 'AAAA' })
    $TestNetConnectionResult.BasicNameResolution = @(Resolve-DnsName $ComputerName -ErrorAction SilentlyContinue | Where-Object { $_.QueryType -in 'A', 'AAAA', 'PTR' })
    $TestNetConnectionResult.AllNameResolutionResults = $TestNetConnectionResult.BasicNameResolution + $TestNetConnectionResult.DNSOnlyRecords + $TestNetConnectionResult.LLMNRNetbiosRecords | Sort-Object -Unique -Property Address
    return $TestNetConnectionResult
  }

  static [object] ResolveNetworkSecurityDetails([object]$TestNetConnectionResult) {
    $TestNetConnectionResult.IsAdmin = [Connectivity]::CheckIfAdmin()
    $NetworkIsolationInfo = Invoke-CimMethod -Namespace root\standardcimv2 -ClassName MSFT_NetAddressFilter -MethodName QueryIsolationType -Arguments @{
      InterfaceIndex = [uint32]$TestNetConnectionResult.InterfaceIndex
      RemoteAddress  = [string]$TestNetConnectionResult.RemoteAddress
    } -ErrorAction SilentlyContinue
    switch ($NetworkIsolationInfo.IsolationType) {
      1 { $TestNetConnectionResult.NetworkIsolationContext = 'Private Network' }
      0 { $TestNetConnectionResult.NetworkIsolationContext = 'Loopback' }
      2 { $TestNetConnectionResult.NetworkIsolationContext = 'Internet' }
    }
    if ($TestNetConnectionResult.IsAdmin) {
      $TestNetConnectionResult.MatchingIPsecRules = Find-NetIPsecRule -RemoteAddress $TestNetConnectionResult.RemoteAddress -RemotePort $TestNetConnectionResult.RemotePort -Protocol TCP -ErrorAction SilentlyContinue
    }
    return $TestNetConnectionResult
  }

  static [object] DiagnoseRouteSelection([object]$RouteDiagnostics) {
    $RouteDiagnostics.RouteDiagnosticsSucceeded = $false
    $LogFile = ""
    $TraceResults = $null
    if ($RouteDiagnostics.Detailed) {
      Write-Progress -Activity "DiagnoseRouteSelection" -Status "Starting Route Event Tracing" -SecondsRemaining -1 -PercentComplete -1
      do {
        $LogFile = [IO.Path]::GetTempFileName().split('.')[0] + "Test-NetConnection.etl"
      } while (Test-Path -Path $LogFile -ErrorAction SilentlyContinue)
      $TraceResults = netsh trace start tracefile=$LogFile provider=Microsoft-Windows-TCPIP keywords=ut:TcpipRoute report=di perfmerge=no correlation=di session=tnc
    }
    $RouteDiagnostics.ResolvedAddresses = [Connectivity]::ResolveTargetName($RouteDiagnostics.ComputerName)
    if ($null -eq $RouteDiagnostics.ResolvedAddresses) {
      netsh trace stop sessionname=tnc | Out-Null
      return $null
    }
    $RouteDiagnostics.RemoteAddress = $RouteDiagnostics.ResolvedAddresses[0]
    if ($null -eq $RouteDiagnostics.ConstrainSourceAddress) {
      $RouteDiagnostics.ConstrainSourceAddress = if ($RouteDiagnostics.RemoteAddress.AddressFamily -eq [AddressFamily]::InterNetwork) {
        [IPAddress]::Any
      } else {
        [IPAddress]::IPv6Any
      }
    }
    if ($RouteDiagnostics.Detailed -and (Test-Path -Path $LogFile)) {
      if ($RouteDiagnostics.RemoteAddress.AddressFamily -eq [AddressFamily]::InterNetwork) {
        netsh int ipv4 delete destinationcache | Out-Null
      } else {
        netsh int ipv6 delete destinationcache | Out-Null
      }
    }
    try {
      $RouteDiagnostics.SelectedSourceAddress, $RouteDiagnostics.SelectedNetRoute = Find-NetRoute `
        -RemoteIPAddress $RouteDiagnostics.RemoteAddress `
        -LocalIPAddress $RouteDiagnostics.ConstrainSourceAddress `
        -InterfaceIndex $RouteDiagnostics.ConstrainInterfaceIndex -ErrorAction SilentlyContinue
      $RouteDiagnostics.OutgoingNetAdapter = $RouteDiagnostics.SelectedNetRoute | Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue
      $RouteDiagnostics.OutgoingInterfaceAlias = $RouteDiagnostics.SelectedNetRoute.InterfaceAlias
      $RouteDiagnostics.OutgoingInterfaceIndex = $RouteDiagnostics.SelectedNetRoute.InterfaceIndex
      $RouteDiagnostics.OutgoingInterfaceDescription = $RouteDiagnostics.OutgoingNetAdapter.InterfaceDescription
    } catch {
      Write-Debug "Error finding route: $($_.Exception.Message)"
      netsh trace stop sessionname=tnc | Out-Null
      return $null
    }
    if ($RouteDiagnostics.Detailed) {
      $TraceResults += netsh trace stop sessionname=tnc
      if (!(Test-Path -Path $LogFile)) {
        Write-Warning "Error collecting routing events. Error: $TraceResults"
        return $null
      }
      $AllRoutingEvents = Get-WinEvent -Oldest -FilterHashtable @{ Path = $LogFile; ProviderName = 'Microsoft-Windows-TCPIP'; ID = @(1326, 1327, 1370, 1383, 1384) } | Where-Object { $null -ne $_.Message }
      if ($AllRoutingEvents.Count -eq 0) {
        Write-Warning "No TCPIP routing events collected from $LogFile."
      } else {
        $RouteEvents = $AllRoutingEvents | Where-Object { ($_.Id -in 1383, 1384) -and $_.Message.Contains("$($RouteDiagnostics.RemoteAddress) ") }
        foreach ($event in $RouteEvents) {
          if ($RouteDiagnostics.RouteSelectionEvents -notcontains $event.Message) { $RouteDiagnostics.RouteSelectionEvents += "$($event.Message)" }
        }
        $SrcAddrEvents = $AllRoutingEvents | Where-Object { ($_.Id -eq 1326) -and $_.Message.Contains("$($RouteDiagnostics.RemoteAddress) ") }
        foreach ($event in $SrcAddrEvents) {
          if ($RouteDiagnostics.SourceAddressSelectionEvents -notcontains $event.Message) { $RouteDiagnostics.SourceAddressSelectionEvents += "$($event.Message)" }
        }
        $ResolvedAddrs = $RouteDiagnostics.ResolvedAddresses | ForEach-Object { $_.IPAddressToString }
        $DstAddrEvents = $AllRoutingEvents | Where-Object { ($_.Id -eq 1327) -and (($ResolvedAddrs | ForEach-Object { $_.Message.Contains("$_)") }) -contains $true) }
        foreach ($event in $DstAddrEvents) {
          if ($RouteDiagnostics.DestinationAddressSelectionEvents -notcontains $event.Message) { $RouteDiagnostics.DestinationAddressSelectionEvents += "$($event.Message)" }
        }
      }
      $RouteDiagnostics.LogFile = $LogFile
    }
    $RouteDiagnostics.RouteDiagnosticsSucceeded = $true
    return $null
  }

  static [object] TestNetworkPort([string]$ComputerName, [int]$Port, [string]$Protocol, [int]$TcpTimeout, [int]$UdpTimeout) {
    $result = $false
    if ($Protocol -eq 'TCP') {
      $TcpClient = [TcpClient]::new()
      $Connect = $TcpClient.BeginConnect($ComputerName, $Port, $null, $null)
      $Wait = $Connect.AsyncWaitHandle.WaitOne($TcpTimeout, $false)
      if (!$Wait) {
        $TcpClient.Close()
      } else {
        $TcpClient.EndConnect($Connect)
        $TcpClient.Close()
        $result = $true
      }
      $TcpClient.Dispose()
    } elseif ($Protocol -eq 'UDP') {
      $UdpClient = [UdpClient]::new()
      $UdpClient.Client.ReceiveTimeout = $UdpTimeout
      $UdpClient.Connect($ComputerName, $Port)
      $enc = [Text.ASCIIEncoding]::new()
      $byte = $enc.GetBytes([datetime]::Now.ToString())
      [void]$UdpClient.Send($byte, $byte.Length)
      $endpoint = [System.Net.IPEndPoint]::new([IPAddress]::Any, 0)
      try {
        $receivebytes = $UdpClient.Receive([ref]$endpoint)
        if ($enc.GetString($receivebytes)) { $result = $true }
      } catch {
        Write-Error "$ComputerName failed port test on port '$Protocol`:$Port' with error '$($_.Exception.Message)'"
      }
      $UdpClient.Dispose()
    }
    return $result
  }


  static [object] TestPort([string[]]$ComputerName, [uint16[]]$Port, [int]$Timeout, [bool]$TCP, [bool]$UDP) {
    if (!$TCP -and !$UDP) { $TCP = $true }
    $report = @()
    foreach ($c in $ComputerName) {
      foreach ($p in $Port) {
        if ($TCP) {
          $temp = [pscustomobject]@{ ComputerName = $c; Protocol = 'TCP'; Port = $p; Open = $false; Notes = '' }
          $tcpobject = [TcpClient]::new()
          $connect = $tcpobject.BeginConnect($c, $p, $null, $null)
          $wait = $connect.AsyncWaitHandle.WaitOne($Timeout, $false)
          if (!$wait) {
            $tcpobject.Close()
            $temp.Notes = 'Connection to Port Timed Out'
          } else {
            $failed = $false
            try { $null = $tcpobject.EndConnect($connect) } catch { $failed = $true; $temp.Notes = $_.Exception.Message }
            $tcpobject.Close()
            if (!$failed) { $temp.Open = $true; $temp.Notes = "Successful link to $c TCP port $p" }
          }
          $report += $temp
        }
        if ($UDP) {
          $temp = [pscustomobject]@{ ComputerName = $c; Protocol = 'UDP'; Port = $p; Open = $false; Notes = '' }
          $Socket = [Net.Sockets.Socket]::new('InterNetwork', 'Dgram', 'Udp')
          $Socket.SendTimeOut = $Timeout
          $Socket.ReceiveTimeOut = $Timeout
          try {
            $Socket.Connect($c, $p)
            $Buffer = [byte[]]::new(48); $Buffer[0] = 27
            $null = $Socket.Send($Buffer)
            $null = $Socket.Receive($Buffer)
            $temp.Open = $true
          } catch {
            $temp.Notes = $_.Exception.Message
          }
          $Socket.Dispose()
          $report += $temp
        }
      }
    }
    return $report
  }


  static [object] WaitPing([string]$ComputerName, [int]$Timeout, [int]$CheckEvery, [bool]$Offline) {
    $timer = $null
    try {
      $timer = [System.Diagnostics.Stopwatch]::StartNew()
      Write-Verbose "Waiting for [$ComputerName] to become pingable"
      if ($Offline) {
        while (Test-Connection -ComputerName $ComputerName -Quiet -Count 1) {
          Write-Verbose "Waiting for [$ComputerName] to go offline..."
          if ($timer.Elapsed.TotalSeconds -ge $Timeout) { throw "Timeout exceeded waiting for [$ComputerName] to go offline" }
          Start-Sleep -Seconds $CheckEvery
        }
        Write-Verbose "[$ComputerName] is now offline. Waited $([Math]::Round($timer.Elapsed.TotalSeconds, 0)) seconds"
      } else {
        while (!(Test-Connection -ComputerName $ComputerName -Quiet -Count 1)) {
          Write-Verbose "Waiting for [$ComputerName] to become pingable..."
          if ($timer.Elapsed.TotalSeconds -ge $Timeout) { throw "Timeout exceeded waiting for ping to [$ComputerName]" }
          Start-Sleep -Seconds $CheckEvery
        }
        Write-Verbose "Ping now available on [$ComputerName]. Waited $([Math]::Round($timer.Elapsed.TotalSeconds, 0)) seconds"
      }
    } catch {
      Write-Error -Message $_.Exception.Message
    } finally {
      if ($null -ne $timer) { $timer.Stop() }
    }
    return $null
  }
}
