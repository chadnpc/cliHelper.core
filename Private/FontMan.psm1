using module .\Utilities.psm1

class FontMan {
  static [string[]] $FontFolders = [FontMan]::Get_font_folders()
  static [hashtable] $FontFileTypes = @{
    ".fon" = ""
    ".fnt" = ""
    ".ttc" = " (TrueType)"
    ".ttf" = " (TrueType)"
    ".otf" = " (OpenType)"
  }
  static [string] $fontRegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
  FontMan() {
    [FontMan]::init()
  }
  static [int] InstallFont([string]$filePath) {
    return [FontMan]::InstallFont([IO.FileInfo]::new("$([FontMan]::GetUnResolvedPath($filePath))"));
  }
  static [int] InstallFont([System.IO.FileInfo]$fontFile) {
    $filePath = $fontFile.FullName; if (![IO.Path]::Exists($filePath)) {
      throw [System.IO.FileNotFoundException]::new("File Not found!", "$filePath")
    }
    $v = [ProgressUtil]::data.ShowProgress; $hostUI = (Get-Host).UI
    try {
      [string]$filePath = (Resolve-Path $filePath).path
      [string]$fileDir = Split-Path $filePath
      [string]$fileName = Split-Path $filePath -Leaf
      [string]$fileExt = (Get-Item $filePath).extension
      [string]$fileBaseName = $fileName -replace ($fileExt , "")

      $shell = New-Object -com shell.application
      $myFolder = $shell.Namespace($fileDir)
      $fileobj = $myFolder.Items().Item($fileName)
      $fontName = $myFolder.GetDetailsOf($fileobj, 21)
      if ([string]::IsNullOrWhiteSpace($fontName)) {
        $fontName = [FontMan]::GetFontName($fontFile)
      }
      if ([string]::IsNullOrWhiteSpace($fontName)) {
        $fontName = $fileBaseName
      }
      if ([IO.File]::Exists([IO.Path]::Combine($env:windir, 'Fonts', $fontFile.Name))) {
        $v ? (Write-Console "Font '$fontName' already exists!" -f Wheat) : $null
      }
      $v ? (Write-Console "Copying font: $fontName" -f DarkKhaki) : $null
      Copy-Item $filePath -Destination ([FontMan]::FontFolders[0]) -Force
      if (!(Get-ItemProperty -Name $fontName -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue)) {
        $v ? (Write-Console "Registering font: $fontName" -f DarkKhaki) : $null
        New-ItemProperty -Name $fontName -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -PropertyType string -Value $fontFile.Name -Force -ErrorAction SilentlyContinue | Out-Null
      } else {
        $v ? (Write-Console "Font already registered: $fontName" -f Wheat) : $null
      }
      [System.Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null
      $retVal = [FontMan].FontRes32::AddFont([IO.Path]::Combine([FontMan]::FontFolders[0], $fileName))
      if ($retVal -eq 0) {
        $v ? (Write-Console "Font `'$($filePath)`' installation failed" -f Red) : $null
        $hostUI.WriteLine()
        return 1
      } else {
        $v ? (Write-Console "Font `'$($filePath)`' installed successfully" -f Green) : $null
        $hostUI.WriteLine()
        Set-ItemProperty -Path "$([FontMan]::fontRegistryPath)" -Name "$($fontName)$([FontMan]::FontFileTypes.item($fileExt))" -Value "$($fileName)" -type STRING
        return 0
      }
    } catch {
      $v ? (Write-Console "An error occured installing `'$($filePath)`'" -f Red) : $null
      $hostUI.WriteLine()
      $v ? (Write-Console "$($error[0].ToString())" -f Red) : $null
      $hostUI.WriteLine()
      $error.clear()
      return 1
    }
  }
  static [int] RemoveFont([string]$filePath) {
    return [FontMan]::RemoveFont([IO.FileInfo]::new("$([FontMan]::GetUnResolvedPath($filePath))"));
  }
  static [int] RemoveFont([System.IO.FileInfo]$fontFile) {
    $filePath = $fontFile.FullName; if (![IO.Path]::Exists($filePath)) {
      throw [System.IO.FileNotFoundException]::new("File Not found!", "$filePath")
    }
    $v = [ProgressUtil]::data.ShowProgress
    $hostUI = (Get-Host).UI
    $fontFinalPath = [IO.Path]::Combine([FontMan]::FontFolders[0], $filePath)
    try {
      $retVal = [FontMan].FontRes32::RemoveFont($fontFinalPath)
      $fontName = [FontMan]::GetFontName($fontFile)
      if ($retVal -eq 0) {
        $v ? (Write-Console "Font `'$filePath`' removal failed" -f Red) : $null
        $hostUI.WriteLine()
        return 1
      } else {
        # Get Registry StringName From Value :
        [string]$keyPath = [FontMan]::fontRegistryPath;
        $fontRegistryvaluename = Invoke-Command -ScriptBlock {
          $pattern = [Regex]::Escape($fullpath)
          foreach ($property in (Get-ItemProperty $keyPath).PsObject.Properties) {
            ## Skip the property if it was one PowerShell added
            if (($property.Name -eq "PSPath") -or ($property.Name -eq "PSChildName")) {
              continue
            }
            ## Search the text of the property
            $propertyText = "$($property.Value)"
            if ($propertyText -match $pattern) {
              "$($property.Name)"
            }
          }
        }
        $v ? (Write-Console "Font: $fontRegistryvaluename" -f DarkKhaki) : $null
        if ($fontRegistryvaluename -ne "") {
          Remove-ItemProperty -Path ([FontMan]::fontRegistryPath) -Name $fontRegistryvaluename
        } else {
          $v ? (Write-Console "Font $fontName not registered!" -f Red) : $null
        }

        if ([IO.Path]::Exists($fontFinalPath)) {
          $v ? (Write-Console "Removing font: $fontFile" -f DarkKhaki) : $null
          Remove-Item $fontFinalPath -Force
        } else {
          $v ? (Write-Console "Font does not exist: $fontFile" -f Wheat) : $null
        }

        if ($null -ne $error[0]) {
          $v ? (Write-Console "An error occured removing $`'$filePath`'" -f Red) : $null
          $hostUI.WriteLine()
          $v ? (Write-Console "$($error[0].ToString())" -f Red) : $null
          $hostUI.WriteLine()
          $error.clear()
        } else {
          $v ? (Write-Console "Font `'$filePath`' removed successfully" -f Green) : $null
          $hostUI.WriteLine()
        }
        return 0
      }
    } catch {
      $v ? (Write-Console "An error occured removing `'$filePath`'" -f Red) : $null
      $hostUI.WriteLine()
      $v ? (Write-Console "$($error[0].ToString())" -f Red) : $null
      $hostUI.WriteLine()
      $error.clear()
      return 1
    }
  }
  static [string] GetFontName([string]$fontFile) {
    return [FontMan]::GetFontName([System.IO.FileInfo]::new("$([FontMan]::GetUnResolvedPath($fontFile))"))
  }
  static [string] GetFontName([System.IO.FileInfo]$fontFile) {
    Add-Type -AssemblyName PresentationCore
    $fp = $fontFile.FullName; $gt = New-Object Windows.Media.GlyphTypeface("$fp")
    $family = $gt.Win32FamilyNames['en-us']; $ext = $fontFile.Extension
    if ($null -eq $family) { $family = $gt.Win32FamilyNames.Values.Item(0) }
    $face = $gt.Win32FaceNames['en-us']
    if ($null -eq $face) { $face = $gt.Win32FaceNames.Values.Item(0) }
    $fontName = ("$family $face").Trim()
    $fontName = $fontName + [FontMan]::FontFileTypes.$ext
    return $fontName
  }
  static [string[]] GetInstalledFonts() {
    Add-Type -AssemblyName System.Drawing
    $familyList = @(); $installedFontCollection = New-Object System.Drawing.Text.InstalledFontCollection
    $fontFamilies = $installedFontCollection.Families
    foreach ($fontFamily in $fontFamilies) { $familyList += $fontFamily.Name }
    return $familyList
  }
  static [bool] IsFontInstalled([string]$FontName) {
    $fonts = [FontMan]::GetInstalledFonts()
    return $fonts -contains $FontName
  }
  # static [System.Drawing.Font] NewFont([string]$Name) {
  #     Add-Type -AssemblyName 'System.Drawing'
  #     $fontFamily = [System.Drawing.FontFamily]::New("$Name")
  #     return [System.Drawing.Font]::new($fontFamily, 8, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point)
  # }
  static [string] GetResolvedPath([string]$Path) {
    return [FontMan]::GetResolvedPath($((Get-Variable ExecutionContext).Value.SessionState), $Path)
  }
  static [string] GetResolvedPath([System.Management.Automation.SessionState]$session, [string]$Path) {
    $paths = $session.Path.GetResolvedPSPathFromPSPath($Path);
    if ($paths.Count -gt 1) {
      throw [System.IO.IOException]::new([string]::Format([cultureinfo]::InvariantCulture, "Path {0} is ambiguous", $Path))
    } elseif ($paths.Count -lt 1) {
      throw [System.IO.IOException]::new([string]::Format([cultureinfo]::InvariantCulture, "Path {0} not Found", $Path))
    }
    return $paths[0].Path
  }
  static [string] GetUnResolvedPath([string]$Path) {
    return [FontMan]::GetUnResolvedPath($((Get-Variable ExecutionContext).Value.SessionState), $Path)
  }
  static [string] GetUnResolvedPath([System.Management.Automation.SessionState]$session, [string]$Path) {
    return $session.Path.GetUnresolvedProviderPathFromPSPath($Path)
  }
  static [string[]] Get_font_folders() {
    return ([cryptobase]::GetHostOs()).Equals("Windows") ? $(New-Object -COM "Shell.Application").NameSpace(20).Self.Path : $(((fc-list).Split("`n") | Select-Object @{l = 'Fonts'; e = { ([IO.FileInfo]$_.Split(":")[0]).Directory } }).Fonts.Parent.FullName | Sort-Object -Unique)
  }
  static hidden [void] init() {
    if ($null -eq [FontMan].FontRes32) {
      Add-Type -TypeDefinition ([System.Text.Encoding]::UTF8.GetString([convert]::FromBase64String('dXNpbmcgU3lzdGVtOwp1c2luZyBTeXN0ZW0uSU87CnVzaW5nIFN5c3RlbS5UZXh0Owp1c2luZyBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYzsKdXNpbmcgU3lzdGVtLlJ1bnRpbWUuSW50ZXJvcFNlcnZpY2VzOwpwdWJsaWMgZW51bSBXTSA6IHVpbnQgeyBGT05UQ0hBTkdFID0gMHgwMDFEIH0KcHVibGljIGNsYXNzIEZvbnRSZXMzMiB7CiAgICBwcml2YXRlIHN0YXRpYyBJbnRQdHIgSFdORF9CUk9BRENBU1QgPSBuZXcgSW50UHRyKDB4ZmZmZik7CiAgICBwcml2YXRlIHN0YXRpYyBJbnRQdHIgSFdORF9UT1AgPSBuZXcgSW50UHRyKDApOwogICAgcHJpdmF0ZSBzdGF0aWMgSW50UHRyIEhXTkRfQk9UVE9NID0gbmV3IEludFB0cigxKTsKICAgIHByaXZhdGUgc3RhdGljIEludFB0ciBIV05EX1RPUE1PU1QgPSBuZXcgSW50UHRyKC0xKTsKICAgIHByaXZhdGUgc3RhdGljIEludFB0ciBIV05EX05PVE9QTU9TVCA9IG5ldyBJbnRQdHIoLTIpOwogICAgcHJpdmF0ZSBzdGF0aWMgSW50UHRyIEhXTkRfTUVTU0FHRSA9IG5ldyBJbnRQdHIoLTMpOwogICAgW0RsbEltcG9ydCgiZ2RpMzIuZGxsIiwgU2V0TGFzdEVycm9yID0gdHJ1ZSwgQ2hhclNldCA9IENoYXJTZXQuQXV0byldCiAgICBwdWJsaWMgc3RhdGljIGV4dGVybiBpbnQgQWRkRm9udFJlc291cmNlKHN0cmluZyBscEZpbGVuYW1lKTsKICAgIFtEbGxJbXBvcnQoImdkaTMyLmRsbCIsIFNldExhc3RFcnJvciA9IHRydWUsIENoYXJTZXQgPSBDaGFyU2V0LkF1dG8pXQogICAgcHVibGljIHN0YXRpYyBleHRlcm4gaW50IFJlbW92ZUZvbnRSZXNvdXJjZShzdHJpbmcgbHBGaWxlTmFtZSk7CiAgICBbRGxsSW1wb3J0KCJ1c2VyMzIuZGxsIiwgU2V0TGFzdEVycm9yID0gdHJ1ZSwgQ2hhclNldCA9IENoYXJTZXQuQXV0byldCiAgICBwdWJsaWMgc3RhdGljIGV4dGVybiBpbnQgU2VuZE1lc3NhZ2UoSW50UHRyIGhXbmQsIFdNIHdNc2csIEludFB0ciB3UGFyYW0sIEludFB0ciBsUGFyYW0pOwogICAgW3JldHVybjogTWFyc2hhbEFzKFVubWFuYWdlZFR5cGUuQm9vbCldCiAgICBbRGxsSW1wb3J0KCJ1c2VyMzIuZGxsIiwgU2V0TGFzdEVycm9yID0gdHJ1ZSwgQ2hhclNldCA9IENoYXJTZXQuQXV0byldCiAgICBwdWJsaWMgc3RhdGljIGV4dGVybiBib29sIFBvc3RNZXNzYWdlKEludFB0ciBoV25kLCBXTSBNc2csIEludFB0ciB3UGFyYW0sIEludFB0ciBsUGFyYW0pOwogICAgcHVibGljIHN0YXRpYyBpbnQgQWRkRm9udChzdHJpbmcgZm9udEZpbGVQYXRoKSB7CiAgICAgICAgRmlsZUluZm8gZm9udEZpbGUgPSBuZXcgRmlsZUluZm8oZm9udEZpbGVQYXRoKTsKICAgICAgICBpZiAoIWZvbnRGaWxlLkV4aXN0cykgeyByZXR1cm4gMDsgfQogICAgICAgIHRyeSAgewogICAgICAgICAgICBpbnQgcmV0VmFsID0gQWRkRm9udFJlc291cmNlKGZvbnRGaWxlUGF0aCk7CiAgICAgICAgICAgIGJvb2wgcG9zdGVkID0gUG9zdE1lc3NhZ2UoSFdORF9CUk9BRENBU1QsIFdNLkZPTlRDSEFOR0UsIEludFB0ci5aZXJvLCBJbnRQdHIuWmVybyk7CiAgICAgICAgICAgIHJldHVybiByZXRWYWw7CiAgICAgICAgfSBjYXRjaCB7CiAgICAgICAgICAgIHJldHVybiAwOwogICAgICAgIH0KICAgIH0KICAgIHB1YmxpYyBzdGF0aWMgaW50IFJlbW92ZUZvbnQoc3RyaW5nIGZvbnRGaWxlTmFtZSkgewogICAgICAgIHRyeSB7CiAgICAgICAgICAgIGludCByZXRWYWwgPSBSZW1vdmVGb250UmVzb3VyY2UoZm9udEZpbGVOYW1lKTsKICAgICAgICAgICAgYm9vbCBwb3N0ZWQgPSBQb3N0TWVzc2FnZShIV05EX0JST0FEQ0FTVCwgV00uRk9OVENIQU5HRSwgSW50UHRyLlplcm8sIEludFB0ci5aZXJvKTsKICAgICAgICAgICAgcmV0dXJuIHJldFZhbDsKICAgICAgICB9IGNhdGNoIHsKICAgICAgICAgICAgcmV0dXJuIDA7CiAgICAgICAgfQogICAgfQp9')));
      [FontMan].psobject.Properties.Add([PsScriptProperty]::new('FontRes32',
          { return (New-Object FontRes32) }
        )
      )
    }
  }
}


