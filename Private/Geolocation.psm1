
class Geolocation {
  static [object] GetGeoLocIp([string]$IPAddress) {
    $response     = $null
    $errorMessage = $null
    try {
      $httpResponse = Invoke-WebRequest -UseBasicParsing -Uri "https://stat.ripe.net/data/geoloc/data.json?resource=$IPAddress"
      if ($httpResponse) {
        $jsonResponse = $httpResponse | ConvertFrom-Json
        if ($jsonResponse.data.locations.Count -gt 0) {
          $sb = [System.Text.StringBuilder]::new()
          foreach ($location in $jsonResponse.data.locations) {
            [void]$sb.AppendLine("$($location.City) $($location.country)")
          }
          $response = $sb.ToString().TrimEnd()
        } else {
          $errorMessage = 'Not Found'
        }
      }
    } catch [System.Net.WebException] {
      switch ($_.Exception.Response.StatusCode) {
        'BadRequest'         { $errorMessage = 'Server Error 400' }
        'InternalServerError'{ $errorMessage = 'Server Error 500' }
        default              { $errorMessage = "Server Error: $($_.Exception)" }
      }
    } catch {
      $errorMessage = "General error: $($_.Exception)"
    }
    if ($errorMessage) { Write-Error "$errorMessage`n:(" }
    return $response
  }

  static [object] GetIPlocation([string]$IPaddress) {
    $result = $null
    try {
      if ([string]::IsNullOrEmpty($IPaddress)) { $IPaddress = Read-Host "Enter IP address to locate" }
      $result = Invoke-RestMethod -Method Get -Uri "http://ip-api.com/json/$IPaddress"
    } catch {
      Write-Verbose "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
    }
    return $result
  }

  static [object] GetISSposition() {
    <#
    .SYNOPSIS
      Gets the current position of the ISS.
    .DESCRIPTION
      Queries the Open Notify API for the current position of the International Space Station.
    #>
    $result = $null
    try {
      $ISS = (Invoke-WebRequest "http://api.open-notify.org/iss-now.json" -UserAgent "curl" -UseBasicParsing).Content | ConvertFrom-Json
      $result = [PSCustomObject]@{
        Longitude = $ISS.iss_position.longitude
        Latitude  = $ISS.iss_position.latitude
        Timestamp = $ISS.timestamp
        Message   = "The ISS is at $($ISS.iss_position.longitude)° lon and $($ISS.iss_position.latitude)° lat."
      }
      Write-Host $result.Message -ForegroundColor Cyan
    } catch {
      Write-Verbose "Errored: $($_.CategoryInfo.Category) : $($_.CategoryInfo.Reason) : $($_.Exception.Message)"
    }
    return $result
  }
}
