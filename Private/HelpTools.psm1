
class HelpTools {
  static [object] GetCimHelp([String]$Class, [String]$Namespace, [bool] $Detailed, [String]$Property, [String]$Method) {
    $Type = ''; $PropertyObject = $null
    $HelpUrl = Get-CimUri -Type $Type -Method $Method -Property $Property
    $CimClass = Get-CimClass $Class -Namespace $Namespace
    $LocalizedClass = Get-WmiClassInfo $Class -Namespace $Namespace

    $HelpObject = New-Object PSObject -Property @{
      Details      = New-Object PSObject -Property @{
        Name        = $CimClass.CimClassName
        Namespace   = $CimClass.CimSystemProperties.Namespace
        SuperClass  = $CimClass.CimSuperClass.ToString()
        Description = @($LocalizedClass.Qualifiers["Description"].Value -split "`n" | ForEach-Object {
            $Paragraph = New-Object PSObject -Property @{Text = $_.Trim() }
            $Paragraph.PSObject.TypeNames.Insert(0, "CimParaTextItem")
            $Paragraph
          }
        )
      }
      Properties   = @{}
      Methods      = @{}
      RelatedLinks = @(
        New-Object PSObject -Property @{Title = "Online Version"; Link = $HelpUrl }
      )
    }

    $HelpObject.Details.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Details")
    $HelpObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo")
    $HelpObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Cim")
    if ($Detailed) {
      $HelpObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Cim#DetailedView")
    }

    foreach ($CimProperty in $LocalizedClass.Properties) {
      $PropertyObject = New-Object PSObject -Property @{
        Name         = $CimProperty.Name
        type         = $CimProperty.Type
        Description  = @($CimProperty.Qualifiers["Description"].Value -split "`n" | ForEach-Object {
            $Paragraph = New-Object PSObject -Property @{Text = $_.Trim() }
            $Paragraph.PSObject.TypeNames.Insert(0, "CimParaTextItem")
            $Paragraph
          })
        RelatedLinks = @(
          New-Object PSObject -Property @{Title = "Online Version"; Link = $HelpUrl }
        )
      }
      $PropertyObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Cim#Property")
      $HelpObject.Properties.Add($CimProperty.Name, $PropertyObject)
    }

    foreach ($CimMethod in $CimClass.CimClassMethods) {
      $MethodHelp = $LocalizedClass.Methods[$CimMethod.Name]

      $MethodObject = New-Object PSObject -Property @{
        Name         = $CimMethod.Name
        Static       = $CimMethod.Qualifiers["Static"].Value
        Constructor  = $CimMethod.Qualifiers["Constructor"].Value
        Description  = $null
        Parameters   = @{}
        RelatedLinks = @(
          New-Object PSObject -Property @{Title = "Online Version"; Link = $HelpUrl }
        )
      }
      $MethodObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Cim#Method")

      $MethodObject.Description = @($MethodHelp.Qualifiers["Description"].Value -split "`n" | ForEach-Object {
          $Paragraph = New-Object PSObject -Property @{Text = $_.Trim() }
          $Paragraph.PSObject.TypeNames.Insert(0, "CimParaTextItem")
          $Paragraph
        }
      )

      $CimMethod.Parameters | ForEach-Object {
        if ($_.Qualifiers["In"]) {
          $MethodObject.Parameters[$_.Name] = New-Object PSObject -Property @{
            Name        = $_.Name
            Type        = $_.CimType
            ID          = [int]$_.Qualifiers["ID"].Value
            Description = $null
            In          = $true
          }
        }
        if ($_.Qualifiers["Out"]) {
          $MethodObject.Parameters[$_.Name] = New-Object PSObject -Property @{
            Name        = $_.Name
            Type        = $_.CimType
            ID          = [int]$_.Qualifiers["ID"].Value
            Description = $null
            In          = $false
          }
        }
      }
      $HelpObject.Methods.Add($CimMethod.Name, $MethodObject)
    }

    if ($Property) {
      $PropertyObject = $HelpObject.Properties[$Property]

      if ($PropertyObject) {
        Add-Member -InputObject $PropertyObject -Name Class -Value $HelpObject.Details.Name -MemberType NoteProperty
        Add-Member -InputObject $PropertyObject -Name Namespace -Value $HelpObject.Details.Namespace -MemberType NoteProperty
        Add-Member -InputObject $PropertyObject -Name SuperClass -Value $HelpObject.Details.SuperClass -MemberType NoteProperty
        $PropertyObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Cim#PropertyDetail")
        return $PropertyObject
      } else {
        throw "Property named '$Property' not found."
      }
    } elseif ($Method) {
      $MethodObject = $HelpObject.Methods[$Method]

      if ($MethodObject) {
        Write-Progress "Retrieving Parameter Descriptions"
        $i, $total = 0, $MethodObject.Parameters.Values.Count

        $MethodHelp = $LocalizedClass.Methods[$Method]
        $MethodObject.Parameters.Values | Where-Object { $_.In } | ForEach-Object {
          Write-Progress "Retrieving Parameter Descriptions" -PercentComplete ($i / $total * 100); $i++

          $ParameterHelp = $MethodHelp.InParameters.Properties | Where-Object Name -EQ $_.Name
          $_.Description = @($ParameterHelp.Qualifiers["Description"].Value -split "`n" | ForEach-Object {
              $Paragraph = New-Object PSObject -Property @{Text = $_.Trim() }
              $Paragraph.PSObject.TypeNames.Insert(0, "CimParaTextItem")
              if ($Paragraph.Text) { $Paragraph }
            })
        }
        $MethodObject.Parameters.Values | Where-Object { !$_.In } | ForEach-Object {
          Write-Progress "Retrieving Parameter Descriptions" -PercentComplete ($i / $total * 100); $i++

          $ParameterHelp = $MethodHelp.OutParameters.Properties | Where-Object Name -EQ $_.Name
          $_.Description = @($ParameterHelp.Qualifiers["Description"].Value -split "`n" | ForEach-Object {
              $Paragraph = New-Object PSObject -Property @{Text = $_.Trim() }
              $Paragraph.PSObject.TypeNames.Insert(0, "CimParaTextItem")
              if ($Paragraph.Text) { $Paragraph }
            }
          )
        }
        Add-Member -InputObject $MethodObject -Name Class -Value $HelpObject.Details.Name -MemberType NoteProperty
        Add-Member -InputObject $MethodObject -Name Namespace -Value $HelpObject.Details.Namespace -MemberType NoteProperty
        Add-Member -InputObject $PropertyObject -Name SuperClass -Value $HelpObject.Details.SuperClass -MemberType NoteProperty
        $MethodObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Cim#MethodDetail")

        Write-Progress "Retrieving Parameter Descriptions" -Completed

        return $MethodObject
      } else {
        throw "Method named '$Method' not found."
      }
    } else {
      return $HelpObject
    }
  }

  static [object] GetCimUri([Microsoft.Management.Infrastructure.CimClass]$Type, [String]$Method, [String]$Property) {
    $Culture = $(Get-Variable Host).Value.CurrentCulture.Name
    $TypeName = $Type.CimClassName -replace "_", "-"
    if ($Method) {
      # $Page = "$TypeName#methods"
      $Page = "$Method-method-in-class-$TypeName"
    } elseif ($Property) {
      $Page = "$TypeName#properties"
    } else {
      $Page = $TypeName
    }
    return New-Object System.Uri "https://docs.microsoft.com/$Culture/windows/desktop/CIMWin32Prov/$Page"
  }
  static [object] GetCommandSyntax([String]$Name) {
    $r = foreach ($provider in (Get-PSProvider)) {
      if ((Get-Host).name -match "console") {
        "$([char]0x1b)[1;4;38;5;155m$($provider.name)$([char]0x1b)[0m"
      } else {
        $provider.name
      }
      #get first drive
      $path = "$($provider.drives[0]):\"
      Push-Location
      Set-Location $path
      $syn = Get-Command -Name $Name -Syntax | Out-String
      $get = Get-Command -Name $name

      $dynamic = ($get.parameters.GetEnumerator() | Where-Object { $_.value.IsDynamic }).key
      Pop-Location
      if ($dynamic) {
        Write-Verbose "...found $($dynamic.count) dynamic parameters"
        Write-Verbose "...$($dynamic -join ",")"
        foreach ($param in $dynamic) {
          if ((Get-Host).name -match 'console') {
            $syn = $syn -replace "\b$param\b", "$([char]0x1b)[1;38;5;213m$param$([char]0x1b)[0m"
          } else {
            #must be in the PowerShell ISE so don't use any ANSI formatting
          }
        }
      }
      $syn
    }
    return $r
  }
  static [object] GetHelpLocation([type]$Type) {
    # get documentation filename, assembly location and assembly codebase
    $DocFilename = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetFileName($Type.assembly.Location), ".xml")
    $Location = [System.IO.Path]::GetDirectoryName($Type.assembly.Location)
    $CodeBase = (New-Object System.Uri $Type.assembly.CodeBase).LocalPath

    Write-Verbose ("Documentation file is '$DocFilename.'")

    ## try localized location (typically newer than base framework dir)
    $FrameworkDir = "${env:windir}\Microsoft.NET\framework\v2.0.50727"
    $Language = [System.Globalization.CultureInfo]::CurrentUICulture.Parent.Name
    $PathList = @(
      "$FrameworkDir\$Language\$DocFilename",
      "$FrameworkDir\$DocFilename",
      "$Location\$DocFilename",
      "$CodeBase\$DocFilename"
    )
    $r = @()
    foreach ($Path in $PathList) {
      if (Test-Path $Path) {
        $r += $Path
      }
    }
    return $r

    # if (!$Online)
    # {
    #     # try localized location (typically newer than base framework dir)
    #     $frameworkDir = "${env:windir}\Microsoft.NET\framework\v2.0.50727"
    #     $lang = [system.globalization.cultureinfo]::CurrentUICulture.parent.name

    #     # I love looking at this. A Duff's Device for PowerShell.. well, maybe not.
    #     switch
    #         (
    #         "${frameworkdir}\${lang}\$docFilename",
    #         "${frameworkdir}\$docFilename",
    #         "$location\$docFilename",
    #         "$codebase\$docFilename"
    #         )
    #     {
    #         { test-path $_ } { $_; return; }

    #         default
    #         {
    #             # try next path
    #             continue;
    #         }
    #     }
    # }

    # # failed to find local docs, is it from MS?
    # if ((Get-ObjectVendor $type) -like "*Microsoft*")
    # {
    #     # drop locale - site will redirect to correct variation based on browser accept-lang
    #     $suffix = ""
    #     if ($Members.IsPresent)
    #     {
    #         $suffix = "_members"
    #     }

    #     new-object uri ("http://msdn.microsoft.com/library/{0}{1}.aspx" -f $type.fullname,$suffix)

    #     return
    # }
  }
  static [object] GetHelpUri([type]$Type, [String]$Member) {
    ## Needed for UrlEncode()
    Add-Type -AssemblyName System.Web
    $uri = $null
    $Vendor = Get-ObjectVendor $Type
    if ($Vendor -like "*Microsoft*") {
      ## drop locale - site will redirect to correct variation based on browser accept-lang
      $Suffix = ""
      if ($Member -eq "_members") {
        $Suffix = "_members"
      } elseif ($Member) {
        $Suffix = ".$Member"
      }

      $Query = [System.Web.HttpUtility]::UrlEncode(("{0}{1}" -f $Type.FullName, $Suffix))
      $uri = New-Object System.Uri "http://msdn.microsoft.com/library/$Query.aspx"
    } else {
      $Suffix = ""
      if ($Member -eq "_members") {
        $Suffix = " members"
      } elseif ($Member) {
        $Suffix = ".$Member"
      }

      if ($Vendor) {
        $Query = [System.Web.HttpUtility]::UrlEncode(("`"{0}`" {1}{2}" -f $Vendor, $Type.FullName, $Suffix))
      } else {
        $Query = [System.Web.HttpUtility]::UrlEncode(("{0}{1}" -f $Type.FullName, $Suffix))
      }
      $uri = New-Object System.Uri "http://www.bing.com/results.aspx?q=$Query"
    }
    return $uri
  }
  static [object] GetLocalizedNamespace([Object]$NameSpace, [Int32]$cultureID, [bool]$quiet) {
    #First, get a list of all localized namespaces under the current namespace
    $localizedNamespaces = Get-CimInstance -Namespace $NameSpace -Class "__Namespace" | Where-Object { $_.Name -like "ms_*" }
    if ($null -eq $localizedNamespaces) {
      if (!$quiet) {
        Write-Warning "Could not get a  list of localized namespaces"
      }
      return $null
    }
    return ("$namespace\ms_{0:x}" -f $cultureID)
  }
  static [object] GetManagedDll([String]$FilePath) {
    $output = @()
    $Path = Resolve-Path $FilePath
    if (! [IO.File]::Exists($Path)) {
      throw "$Path does not exist."
    }
    $FileBytes = [System.IO.File]::ReadAllBytes($Path)
    if (($FileBytes[0..1] | ForEach-Object { [Char]$_ }) -join '' -cne 'MZ') {
      throw "$Path is not a valid executable."
    }
    $Length = $FileBytes.Length
    $CompressedStream = New-Object IO.MemoryStream
    $DeflateStream = New-Object IO.Compression.DeflateStream ($CompressedStream, [IO.Compression.CompressionMode]::Compress)
    $DeflateStream.Write($FileBytes, 0, $FileBytes.Length)
    $DeflateStream.Dispose()
    $CompressedFileBytes = $CompressedStream.ToArray()
    $CompressedStream.Dispose()
    $EncodedCompressedFile = [Convert]::ToBase64String($CompressedFileBytes)

    Write-Verbose "Compression ratio: $(($EncodedCompressedFile.Length/$FileBytes.Length).ToString('#%'))"

    $Output = @"
`$EncodedCompressedFile = @'
$EncodedCompressedFile
'@
`$DeflatedStream = New-Object IO.Compression.DeflateStream([IO.MemoryStream][Convert]::FromBase64String(`$EncodedCompressedFile),[IO.Compression.CompressionMode]::Decompress)
`$UncompressedFileBytes = New-Object Byte[]($Length)
`$DeflatedStream.Read(`$UncompressedFileBytes, 0, $Length) | Out-Null
[Reflection.Assembly]::Load(`$UncompressedFileBytes)
"@
    return $Output
  }

  static [object] GetNetHelp([type]$Type, [bool] $Detailed, [String]$Property, [String]$Method) {


    # if ($Docs = Get-HelpLocation $Type) {
    #     Write-Verbose ("Found '$Docs'.")

    #     $TypeName = $Type.FullName
    #     if ($Method) {
    #         $Selector = "M:$TypeName.$Method"
    #     } else {  ## TODO:  Property?
    #         $Selector = "T:$TypeName"
    #     }

    #     ## get summary, if possible
    #     $Help = Import-LocalNetHelp $Docs $Selector

    #     if ($Help) {
    #         $Help #| Format-AssemblyHelp
    #     } else {
    #         Write-Warning "While some local documentation was found, it was incomplete."
    #     }
    # }

    $HelpUrl = Get-HelpUri $Type
    $HelpObject = New-Object PSObject -Property @{
      Details      = New-Object PSObject -Property @{
        Name       = $Type.Name
        namespace  = $Type.namespace
        SuperClass = $Type.BaseType
      }
      Properties   = @{}
      Constructors = @()
      Methods      = @{}
      RelatedLinks = @(
        New-Object PSObject -Property @{Title = "Online Version"; Link = $HelpUrl }
      )
    }
    $HelpObject.Details.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Details")
    $HelpObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo")
    if ($Detailed) {
      $HelpObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net#DetailedView")
      # Write-Error "Local detailed help not available for type '$Type'."
    } else {
      $HelpObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net")
    }

    foreach ($NetProperty in $Type.DeclaredProperties) {
      $PropertyObject = New-Object PSObject -Property @{
        Name = $NetProperty.Name
        Type = $NetProperty.PropertyType
      }
      $PropertyObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net#Property")
      $HelpObject.Properties.Add($NetProperty.Name, $PropertyObject)
    }

    foreach ($NetConstructor in $Type.DeclaredConstructors | Where-Object { $_.IsPublic }) {
      $ConstructorObject = New-Object PSObject -Property @{
        Name       = $Type.Name
        Namespace  = $Type.Namespace
        Parameters = $NetConstructor.GetParameters()
      }
      $ConstructorObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net#Constructor")

      $HelpObject.Constructors += $ConstructorObject
    }

    foreach ($NetMethod in $Type.DeclaredMethods | Where-Object { $_.IsPublic -and (!$_.IsSpecialName) } | Group-Object Name) {
      $MethodObject = New-Object PSObject -Property @{
        Name        = $NetMethod.Name
        Static      = $NetMethod.Group[0].IsStatic
        Constructor = $NetMethod.Group[0].IsConstructor
        ReturnType  = $NetMethod.Group[0].ReturnType
        Overloads   = @(
          $NetMethod.Group | ForEach-Object {
            $MethodOverload = New-Object PSObject -Property @{
              Name       = $NetMethod.Name
              Static     = $_.IsStatic
              ReturnType = $_.ReturnType
              Parameters = @(
                $_.GetParameters() | ForEach-Object {
                  New-Object PSObject -Property @{
                    Name          = $_.Name
                    ParameterType = $_.ParameterType
                  }
                }
              )
              Class      = $HelpObject.Details.Name
              Namespace  = $HelpObject.Details.Namespace
            }
            $MethodOverload.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net#MethodOverload")
            $MethodOverload
          }
        )
      }
      $MethodObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net#Method")

      $HelpObject.Methods.Add($NetMethod.Name, $MethodObject)
    }

    $DownloadOnlineHelp = $true
    if ($Property) {
      $PropertyObject = $HelpObject.Properties[$Property]

      if ($PropertyObject) {
        $PropertyHelpUrl = Get-HelpUri $Type -Member $Property
        Add-Member -InputObject $PropertyObject -Name Class -Value $HelpObject.Details.Name -MemberType NoteProperty
        Add-Member -InputObject $PropertyObject -Name Namespace -Value $HelpObject.Details.Namespace -MemberType NoteProperty
        Add-Member -InputObject $PropertyObject -Name SuperClass -Value $HelpObject.Details.SuperClass -MemberType NoteProperty
        Add-Member -InputObject $PropertyObject -Name RelatedLinks -Value @(New-Object PSObject -Property @{Title = "Online Version"; Link = $PropertyHelpUrl }) -MemberType NoteProperty
        $PropertyObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net#PropertyDetail")

        if ($DownloadOnlineHelp) {
          $OnlineHelp = Import-OnlineHelp $PropertyHelpUrl
          if ($OnlineHelp) {
            Add-Member -InputObject $PropertyObject -Name Summary -Value $OnlineHelp.Summary -MemberType NoteProperty
          }
        }

        return $PropertyObject
      } else {
        throw "Property named '$Property' not found."
      }
    } elseif ($Method) {
      $MethodObject = $HelpObject.Methods[$Method]

      if ($MethodObject) {
        $MethodHelpUrl = Get-HelpUri $Type -Member $Method
        Add-Member -InputObject $MethodObject -Name Class -Value $HelpObject.Details.Name -MemberType NoteProperty
        Add-Member -InputObject $MethodObject -Name Namespace -Value $HelpObject.Details.Namespace -MemberType NoteProperty
        Add-Member -InputObject $MethodObject -Name SuperClass -Value $HelpObject.Details.SuperClass -MemberType NoteProperty
        Add-Member -InputObject $MethodObject -Name RelatedLinks -Value @(New-Object PSObject -Property @{Title = "Online Version"; Link = $MethodHelpUrl }) -MemberType NoteProperty
        $MethodObject.PSObject.TypeNames.Insert(0, "ObjectHelpInfo#Net#MethodDetail")

        if ($DownloadOnlineHelp) {
          $OnlineHelp = Import-OnlineHelp $MethodHelpUrl
          if ($OnlineHelp) {
            Add-Member -InputObject $MethodObject -Name Summary -Value $OnlineHelp.Summary -MemberType NoteProperty
          }
        }

        return $MethodObject
      } else {
        throw "Method named '$Method' not found."
      }
    } else {
      if ($DownloadOnlineHelp) {
        $OnlineHelp = Import-OnlineHelp $HelpUrl
        if ($OnlineHelp) {
          Add-Member -InputObject $HelpObject.Details -Name Summary -Value $OnlineHelp.Summary -MemberType NoteProperty
        }
      }
      return $HelpObject
    }
  }
  static [object] GetObjectHelp([PSObject]$Object, [bool] $Detailed, [String]$Method, [String]$Property, [bool] $Online) {
    $help = $null
    $Type = $null
    $TypeName = $null
    # $Selector = $null

    Write-Verbose "Start processing..."
    Write-Verbose ("Input object (Type:" + $Object.GetType() + ", IsType:" + ($Object -is [System.type]) + ")")
    if ($Object -is [Management.Automation.PSMemberInfo]) {
      if ($Object -is [System.Management.Automation.PSMethod]) {
        $Method = $Object.Name
        $Type = Resolve-MemberOwnerType $Object
      } else {
        Write-Error "Unable to identify owning time of PSMembers."
        return $null
      }
    } elseif ($Object -is [Microsoft.PowerShell.Commands.MemberDefinition]) {
      if ($Object.MemberType -eq "Method") {
        $Method = $Object.Name
      } else {
        $Property = $Object.Name
      }
      if ($Object.TypeName -match '^System.Management.ManagementObject#(.+)') {
        $Type = $Object.TypeName
      } else {
        $Type = "$($Object.TypeName)" -as [System.type]
      }
    } elseif ($Object -is [Microsoft.Management.Infrastructure.CimClass]) {
      $Type = $Object
    } elseif ($Object -is [Microsoft.Management.Infrastructure.CimInstance]) {
      $Type = $Object.PSBase.CimClass
    } elseif ($Object -is [System.Management.ManagementObject]) {
      $Type = Get-CimClass $Object.__CLASS -Namespace $Object.__NAMESPACE
    } elseif ($Object -is [System.__ComObject]) {
      $Type = $Object
    } elseif ($Object -is [System.String]) {
      switch -regex ($Object) {
        '^\[[^\[\]]+\]$' {
          ## .NET Type (ex: [System.String])
          try {
            $Type = { $Object }.Invoke()
          } catch { $null }
          break
        }
        '^(Win32|CIM)_[\w]+' {
          $Type = Get-CimClass $Object
        }
        ## TODO: WMI / CIM
        default {}
      }
    } elseif ($Object -as [System.type]) {
      $Type = $Object -as [System.type]
    }

    if (!$Type) {
      Write-Error "Could not identify object"
      return $null
    }

    Write-Verbose ("Object (Type:" + $Object.GetType() + ", IsType:" + ($Object -is [System.type]) + ")")
    Write-Verbose ("Method is: $Method")
    Write-Verbose ("Property is: $Property")

    $Culture = $(Get-Variable Host).Value.CurrentCulture.Name
    ## TODO: Support culture parameter?

    if ($Type -is [Microsoft.Management.Infrastructure.CimClass]) {
      if ($Online) {
        if ($Uri = Get-CimUri -Type $Type -Method $Method -Property $Property) {
          [System.Diagnostics.process]::Start($Uri.ToString()) | Out-Null
        }
      } else {
        if ($Method) {
          $help = Get-CimHelp -Class $Type.CimClassName -Namespace $Type.CimSystemProperties.namespace -Method $Method
        } elseif ($Property) {
          $help = Get-CimHelp -Class $Type.CimClassName -Namespace $Type.CimSystemProperties.namespace -Property $Property
        } else {
          $help = Get-CimHelp -Class $Type.CimClassName -Namespace $Type.CimSystemProperties.namespace -Detailed:$Detailed
        }
      }
    } elseif ($Type -is [System.type]) {
      if ($Online) {
        $Member = if ($Method) {
          $Method
        } elseif ($Property) {
          $Property
        } else {
          $null
        }
        if ($Uri = Get-HelpUri $Type -Member $Member) {
          [System.Diagnostics.process]::Start($Uri.ToString()) | Out-Null
        }
      } else {
        if ($Method) {
          $help = Get-NetHelp -Type $Type -Method $Method
        } elseif ($Property) {
          $help = Get-NetHelp -Type $Type -Property $Property
        } else {
          $help = Get-NetHelp -Type $Type -Detailed:$Detailed
        }
      }
    } elseif ($Type -is [System.__ComObject]) {
      if ($Online) {
        if ($Type.PSTypeNames[0] -match 'System\.__ComObject#(.*)$') {
          if (Test-Path "HKLM:\SOFTWARE\Classes\Interface\$($Matches[1])") {
            $TypeKey = (Get-ItemProperty "HKLM:\SOFTWARE\Classes\Interface\$($Matches[1])").'(default)'
            if ('_Application' -contains $TypeKey) {
              # $TypeLib = ..
              # $Version = ..
              # $TypeName = (Get-ItemProperty "HKLM:\SOFTWARE\Classes\TypeLib\$TypeLib\$Version").'(default)'
            } else {
              $TypeName = $TypeKey
            }
          }
        }
        $Uri = "http://social.msdn.microsoft.com/Search/$Culture/?query=$TypeName"
        [System.Diagnostics.process]::Start($uri) | Out-Null
      } else {
        Write-Error "Local help not supported for COM objects."
      }
    }
    return $help
  }
  static [object] GetHelp([object]$Target) {
    return [HelpTools]::GetHelp($Target, $false)
  }
  static [object] GetHelp([object]$Target, [bool]$Detailed) {
    return [HelpTools]::GetObjectHelp($Target, $Detailed, $null, $null, $false)
  }
  static [object] GetOnlineHelp([object]$Target) {
    return [HelpTools]::GetObjectHelp($Target, $false, $null, $null, $true)
  }

  static [object] GetObjectVendor([type] $Type, [bool] $CompanyOnly) {
    $Assembly = $Type.assembly
    $attrib = $Assembly.GetCustomAttributes([Reflection.AssemblyCompanyAttribute], $false) | Select-Object -First 1

    if ($attrib.Company) {
      return $attrib.Company
    } else {
      if ($CompanyOnly) { return  $null }

      # try copyright
      $attrib = $Assembly.GetCustomAttributes([Reflection.AssemblyCopyrightAttribute], $false) | Select-Object -First 1

      if ($attrib.Copyright) {
        return $attrib.Copyright
      }
    }
    Write-Verbose ("Assembly has no [AssemblyCompany] or [AssemblyCopyright] attributes.")
    return $null
  }
  static [object] ResolveMemberOwnerType([System.Management.Automation.PSMethod]$Method) {
    # TODO: support overloads, support interface definitions

    Write-Verbose ("Resolving owning type of '$($Method.Name)'.")
    # hackety-hack - this is prone to breaking in the future
    $TargetType = [System.Management.Automation.PSMethod].GetField("baseObject", "Instance,NonPublic").GetValue($Method)
    if (($TargetType -isnot [System.type]) -and (!$TargetType.__CLASS)) {
      $TargetType = $TargetType.GetType()
    }

    if ($TargetType -is [System.Management.ManagementObject]) {
      $DeclaringType = Get-CimClass $TargetType.__CLASS -Namespace $TargetType.__NAMESPACE
    } else {
      if ($Method.OverloadDefinitions -match "static") {
        $Flags = "Static,Public"
      } else {
        $Flags = "Instance,Public"
      }

      # TODO: support overloads
      $MethodInfo = $TargetType.GetMethods($Flags) | Where-Object { $_.Name -eq $Method.Name } | Select-Object -First 1

      if (!$MethodInfo) {
        # this shouldn't happen.
        throw "Could not resolve owning type."
      }

      $DeclaringType = $MethodInfo.DeclaringType
    }

    Write-Verbose ("Owning type is $($TargetType.FullName). Method declared on $($DeclaringType.FullName).")
    return $DeclaringType
  }
  static [object] SearchWmiHelp([ScriptBlock]$DescriptionExpression, [ScriptBlock]$MethodExpression, [ScriptBlock]$PropertyExpression, [Object] $Namespaces, [Object] $CultureID, [bool] $List) {
    $resultWmiClasses = @{}
    foreach ($namespace in $Namespaces) {
      #First, get a list of all localized namespaces under the current namespace

      $localizedNamespace = Get-LocalizedNamespace $namespace
      if ($null -eq $localizedNamespace) {
        Write-Verbose "Could not get a list of localized namespaces"
        return $null
      }

      $localizedClasses = Get-CimInstance -Namespace $localizedNamespace -Query "select * from meta_class"
      $count = 0
      foreach ($WmiClass in $localizedClasses) {
        $count++
        Write-Progress "Searching Wmi Classes" "$count of $($localizedClasses.Count)" -PercentComplete ($count * 100 / $localizedClasses.Count)
        $classLocation = $localizedNamespace + ':' + $WmiClass.__Class
        $classInfo = Get-WmiClassInfo $classLocation
        [bool]$found = $false
        if ($null -ne $classInfo) {
          if (! $resultWmiClasses.ContainsKey($classLocation)) {
            $resultWmiClasses.Add($wmiClass.__Class, $classInfo)
          }

          $descriptionMatch = [bool]($classInfo.Description | Where-Object $DescriptionExpression)
          $methodMatch = [bool]($classInfo.Methods.GetEnumerator() | Where-Object $MethodExpression)
          $propertyMatch = [bool]($classInfo.Properties.GetEnumerator() | Where-Object $PropertyExpression)

          $found = $descriptionMatch -or $methodMatch -or $propertyMatch

          if (! $found) {
            $resultWmiClasses.Remove($WmiClass.__Class)
          }
        }
      }
    }

    if ($List) {
      $resultWmiClasses.Keys | Sort-Object
    } else {
      $resultWmiClasses.GetEnumerator() | Sort-Object Key
    }
    return $null
  }
}


