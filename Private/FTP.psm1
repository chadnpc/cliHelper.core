
class FTP {
  static [object] GetFTPdir([string]$server) {
    [void][System.Reflection.Assembly]::LoadWithPartialName("system.net")
    $ftp = [System.Net.FtpWebRequest][System.Net.WebRequest]::Create($server)
    $ftp.method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
    $response = $ftp.GetResponse()
    $stream = $response.GetResponseStream()
    $buffer = [System.Byte[]]::new(1024)
    $encoding = [System.Text.ASCIIEncoding]::new()
    $outputBuffer = ""
    $foundMore = $false
    do {
      Start-Sleep -Milliseconds 1000
      $foundMore = $false
      $stream.ReadTimeout = 2000
      do {
        try {
          $read = $stream.Read($buffer, 0, 1024)
          if ($read -gt 0) { $foundMore = $true; $outputBuffer += ($encoding.GetString($buffer, 0, $read)) }
        } catch { $foundMore = $false; $read = 0 }
      } while ($read -gt 0)
    } while ($foundMore)

    $mytable = @()
    foreach ($x in $outputBuffer.Split("`n")) {
      $x = ($x -replace "  ", " " -replace "  ", " " -replace "  ", " ")
      $entry = [PSCustomObject]@{
        date = ($x.Split(" ")[5..7] -join " ")
        size = $x.Split(" ")[4]
        name = $x.Split(" ")[8..99] -join " "
      }
      $mytable += $entry
    }
    foreach ($xx in $mytable) {
      if ($xx.name -like "*backup*") {
        $webclient   = [System.Net.WebClient]::new()
        $backup_name = $xx.name.Trim()
        $web_backup  = "http://www.estel.ee/administrator/backups/$backup_name"
        $new_backup  = "\\diskstation\estelbackup\website\" + (Get-Date -Format "yyyy-MM-dd") + ".tar"
        Write-Host "Downloading $web_backup to $new_backup"
        $webclient.DownloadFile($web_backup, $new_backup)

        $ServerUri = [System.Uri]::new("ftp://www.estel.ee@www.estel.ee/htdocs/administrator/backups/$backup_name")
        if ($ServerUri.Scheme -ne [System.Uri]::UriSchemeFtp) { Write-Warning "Bad URI"; return $null }
        $request             = [System.Net.FtpWebRequest]::Create($ServerUri)
        $request.Method      = [System.Net.WebRequestMethods+Ftp]::DeleteFile
        $request.Credentials = [System.Net.NetworkCredential]::new("d34221f77428", "d2Sn1K")
        $resp = $request.GetResponse()
        Write-Host "Delete status: $($resp.StatusDescription)"
        $resp.Close()
      } else {
        Write-Host "Could not find backup files."
      }
    }
    return $mytable
  }


  static [object] GetFtpFile([string]$url, [string]$fileName, [string]$username, [System.Security.SecureString]$password, [bool]$quiet) {
    if ([string]::IsNullOrEmpty($url))      { Write-Warning "Url parameter is empty.";      return $null }
    if ([string]::IsNullOrEmpty($fileName)) { Write-Warning "FileName parameter is empty."; return $null }
    try {
      $uri = [System.Uri]$url
      if ($uri.IsFile) {
        if ($uri.LocalPath -ne $fileName) { Copy-Item $uri.LocalPath -Destination $fileName -Force }
        return $null
      }
    } catch { $null }
    $ftprequest = [System.Net.FtpWebRequest]::Create($url)
    $explicitProxy = $Env:dotfilesProxyLocation
    if ($null -ne $explicitProxy) {
      $proxy = [System.Net.WebProxy]::new($explicitProxy, $true)
      $explicitProxyPassword = $Env:dotfilesProxyPassword
      if ($null -ne $explicitProxyPassword) {
        $passwd = ConvertTo-SecureString $explicitProxyPassword
        $proxy.Credentials = [System.Management.Automation.PSCredential]::new($Env:dotfilesProxyUser, $passwd)
      }
      $bypassList = $Env:dotfilesProxyBypassList
      if ($null -ne $bypassList -and $bypassList -ne '') {
        $proxy.BypassList = $bypassList.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries)
      }
      if ($Env:dotfilesProxyBypassOnLocal -eq 'true') { $proxy.BypassProxyOnLocal = $true }
      Write-Verbose "Using explicit proxy server '$explicitProxy'."
      $ftprequest.Proxy = $proxy
    }
    $ftprequest.Credentials = [System.Net.NetworkCredential]::new($username, $password)
    $ftprequest.Method      = [System.Net.WebRequestMethods+Ftp]::DownloadFile
    $ftprequest.UseBinary   = $true
    $ftprequest.KeepAlive   = $false
    if ($null -ne $Env:dotfilesRequestTimeout -and $Env:dotfilesRequestTimeout -ne '') {
      $ftprequest.Timeout = $Env:dotfilesRequestTimeout
    }
    $reader = $null; $writer = $null; $ftpresponse = $null
    try {
      $ftpresponse = $ftprequest.GetResponse()
      [long]$goal  = $ftpresponse.ContentLength
      $reader      = $ftpresponse.GetResponseStream()
      $writer      = [System.IO.FileStream]::new($fileName, [System.IO.FileMode]::Create)
      [byte[]]$buf = [byte[]]::new(1048576)
      [long]$total = 0; [long]$count = 0
      do {
        $count  = $reader.Read($buf, 0, $buf.Length)
        $writer.Write($buf, 0, $count)
        if (!$quiet) {
          $total += $count
          if ($goal -gt 0) {
            $pct = [Math]::Truncate(($total / $goal) * 100)
            Write-Progress "Downloading $url" "Saving $total of $goal bytes" -Id 0 -PercentComplete $pct
          } else {
            Write-Progress "Downloading $url" "Saving $total bytes..." -Id 0
          }
        }
      } while ($count -ne 0)
      Write-Verbose "Download of $([System.IO.Path]::GetFileName($fileName)) completed."
    } catch {
      if ($null -ne $ftprequest) {
        $ftprequest.ServicePoint.MaxIdleTime = 0
        $ftprequest.Abort()
        Start-Sleep 1
        [System.GC]::Collect()
      }
      throw "FTP download failed for url '$url'. $($_.Exception.Message)"
    } finally {
      if ($null -ne $reader)      { try { $reader.Close()      } catch { } }
      if ($null -ne $writer)      { try { $writer.Close()      } catch { } }
      if ($null -ne $ftpresponse) { try { $ftpresponse.Close() } catch { } }
    }
    return $null
  }


  static [object] RemoveFtpItem([string]$sourceuri, [string]$ftpusername, [securestring]$ftppassword) {
    $ftprequest             = [System.Net.FtpWebRequest]::Create($sourceuri)
    $ftprequest.Credentials = [System.Net.NetworkCredential]::new($ftpusername, $ftppassword)
    $ftprequest.Method      = [System.Net.WebRequestMethods+Ftp]::DeleteFile
    return $ftprequest.GetResponse()
  }


  static [void] SendToFtp([string]$ftp, [string]$File) {
    $webclient = [System.Net.WebClient]::new()
    $uri       = [System.Uri]::new($ftp)
    $webclient.UploadFile($uri, $File)
  }
}
