
class Proxy {
  static [void] EnableAutoRoutingPAC() { }

  static [string] FindProxyForURL([string]$url, [string]$h0st) {
    if ([shExpMatch]::New((Get-Host), "*.i2p")) {
      return "SOCKS5 127.0.0.1:4447"
    }
    if ([shExpMatch]::New((Get-Host), "*.onion")) {
      return "SOCKS5 127.0.0.1:9050"
    }
    return "DIRECT"
  }

  static [object] TestProxySettings([System.Collections.Hashtable]$CurrentValues, [System.Object]$DesiredValues) {
    $inState = $true
    $proxySettingsToCompare = @(
      'EnableManualProxy'
      'EnableAutoConfiguration'
      'EnableAutoDetection'
      'ProxyServer'
      'ProxyServerBypassLocal'
      'AutoConfigURL'
    )

    foreach ($proxySetting in $proxySettingsToCompare) {
      if ($DesiredValues.ContainsKey($proxySetting) -and ($DesiredValues.$proxySetting -ne $CurrentValues.$proxySetting)) {
        Write-Verbose "ProxySettingMismatch: $proxySetting"
        $inState = $false
      }
    }

    if ($DesiredValues.ContainsKey('ProxyServerExceptions') -and $CurrentValues.ProxyServerExceptions -and @(Compare-Object -ReferenceObject $DesiredValues.ProxyServerExceptions -DifferenceObject $CurrentValues.ProxyServerExceptions).Count -gt 0) {
      Write-Verbose "ProxySettingMismatch: ProxyServerExceptions"
      $inState = $false
    }
    return $inState
  }
}


class shExpMatch {
  shExpMatch() {}
  shExpMatch($h0st, $url) { }
}


