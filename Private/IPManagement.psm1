
class IPManagement {
  static [object] ExpandIPV6([string[]]$IPv6, [bool]$IncludeInput) {
    $output = @()
    foreach ($curIPv6 in $IPv6) {
      $count = 0; $loc = -1
      for ($i = 0; $i -lt $curIPv6.Length; $i++) {
        if ($curIPv6[$i] -eq ':') {
          $count++
          if (($i - 1) -ge 0 -and $curIPv6[$i - 1] -eq ':') { $loc = $i }
        }
      }
      if ($loc -lt 0 -and $count -ne 7) { throw 'Invalid IPv6 Address' }
      $cleaned = $curIPv6
      if ($count -lt 7) {
        $cleaned = $curIPv6.Substring(0, $loc) + (':' * (7 - $count)) + $curIPv6.Substring($loc)
      }
      $result = @()
      foreach ($splt in $cleaned -split ':') {
        $val = 0
        $null = [int]::TryParse($splt, [System.Globalization.NumberStyles]::HexNumber, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$val)
        $result += ('{0:X4}' -f $val)
      }
      $result = $result -join ':'
      if ($IncludeInput) {
        $output += [pscustomobject]@{ OriginalIPv6 = $curIPv6; ExpandedIPv6 = $result }
      } else { $output += $result }
    }
    return $output
  }

  static [string[]] GetIpRange([string[]]$Subnets) {
    $allIPs = @()
    foreach ($subnet in $Subnets) {
      if ($subnet -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$') {
        $IP = ($subnet -split '\/')[0]
        [int]$SubnetBits = ($subnet -split '\/')[1]
        if ($SubnetBits -lt 7 -or $SubnetBits -gt 30) {
          Write-Error -Message 'The number following the / must be between 7 and 30'; continue
        }
        $Octets = $IP -split '\.'
        $IPInBinary = @()
        foreach ($Octet in $Octets) {
          $OctetInBinary = [convert]::ToString($Octet, 2)
          $OctetInBinary = ('0' * (8 - ($OctetInBinary).Length) + $OctetInBinary)
          $IPInBinary += $OctetInBinary
        }
        $IPInBinary = $IPInBinary -join ''
        $HostBits = 32 - $SubnetBits
        $NetworkIDInBinary = $IPInBinary.Substring(0, $SubnetBits)
        $HostIDInBinary = $IPInBinary.Substring($SubnetBits, $HostBits)
        $HostIDInBinary = $HostIDInBinary -replace '1', '0'
        $imax = [convert]::ToInt32(('1' * $HostBits), 2) - 1
        $IPs = @()
        for ($i = 1; $i -le $imax; $i++) {
          $NextHostIDInDecimal = ([convert]::ToInt32($HostIDInBinary, 2) + $i)
          $NextHostIDInBinary = [convert]::ToString($NextHostIDInDecimal, 2)
          $NoOfZerosToAdd = $HostIDInBinary.Length - $NextHostIDInBinary.Length
          $NextHostIDInBinary = ('0' * $NoOfZerosToAdd) + $NextHostIDInBinary
          $NextIPInBinary = $NetworkIDInBinary + $NextHostIDInBinary
          $IPOctets = @()
          for ($x = 1; $x -le 4; $x++) {
            $StartCharNumber = ($x - 1) * 8
            $IPOctetInBinary = $NextIPInBinary.Substring($StartCharNumber, 8)
            $IPOctets += [convert]::ToInt32($IPOctetInBinary, 2)
          }
          $IPs += $IPOctets -join '.'
        }
        $allIPs += $IPs
      } else {
        Write-Error -Message "Subnet [$subnet] is not in a valid format"
      }
    }
    return $allIPs
  }

  static [object] GetSubnetMaskIPv4([int[]]$Length, [bool]$IncludeInput) {
    $result = @()
    foreach ($curLength in $Length) {
      $MaskBinary = ('1' * $curLength).PadRight(32, '0')
      $DottedMaskBinary = $MaskBinary -replace '(.{8}(?!\z))', '${1}.'
      $SubnetMask = ($DottedMaskBinary.Split('.') | ForEach-Object { [Convert]::ToInt32($_, 2) }) -join '.'
      if ($IncludeInput) {
        $result += [pscustomobject]@{ Length = $curLength; SubnetMask = $SubnetMask }
      } else { $result += $SubnetMask }
    }
    return $result
  }

  static [object] TestIsLocalIPv4([System.Net.IPAddress[]]$Target, [System.Net.IPAddress]$Source, [System.Net.IPAddress]$SubnetMask, [bool]$IncludeInput) {
    $SourceResult = $Source.Address -band $SubnetMask.Address; $result = @()
    foreach ($curTarget in $Target) {
      $TargetResult = $curTarget.Address -band $SubnetMask.Address
      $Local = ($SourceResult -eq $TargetResult)
      if ($IncludeInput) {
        $result += [pscustomobject]@{
          Source     = $Source.IPAddressToString
          Target     = $curTarget.IPAddressToString
          SubnetMask = $SubnetMask.IPAddressToString
          Local      = $Local
        }
      } else { $result += $Local }
    }
    return $result
  }

  static [object] TestIsValidIPv4([string[]]$IPAddress, [bool]$IncludeInput) {
    $result = @()
    foreach ($i in $IPAddress) {
      try {
        $check = [ipaddress]$i
        $valid = ($i -eq $check.IPAddressToString)
        if ($IncludeInput) {
          $result += [pscustomobject]@{ Input = "$i"; Result = $valid }
        } else { $valid }
      } catch {
        if ($IncludeInput) {
          $result += [pscustomobject]@{ Input = "$i"; Result = $false }
        } else { $false }
      }
    }
    return $result
  }

  static [object] TestIsValidIPv6([string[]]$IPAddress, [bool]$IncludeInput) {
    $result = @()
    foreach ($i in $IPAddress) {
      try {
        $check = [ipaddress]$i
        $valid = (($i -eq $check.IPAddressToString) -and ($check.AddressFamily -eq 'InterNetworkV6'))
        if ($IncludeInput) {
          $result += [pscustomobject]@{ Input = $i; Result = $valid }
        } else { $valid }
      } catch {
        if ($IncludeInput) {
          $result += [pscustomobject]@{ Input = $i; Result = $false }
        } else { $false }
      }
    }
    return $result
  }
}


