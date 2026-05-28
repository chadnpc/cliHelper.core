using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Collections.Specialized
using namespace System.Management.Automation

using module .\Enums.psm1

# Core Abstractions
class Measurement {
  [int]$Min
  [int]$Max
  Measurement([int]$min, [int]$max) {
    $this.Min = $min
    $this.Max = $max
  }
}

class IAnsiConsoleCursor {
}
class IAnsiConsoleInput {
}
class IExclusivityMode {
}

class IAnsiConsole {
  [object]$Profile
  [IAnsiConsoleCursor]$Cursor
  [IAnsiConsoleInput]$Input
  [IExclusivityMode]$ExclusivityMode
  [object] GetWriter() { return $null }
  [void] Clear() { $this.Clear($true) }
  [void] Clear([bool]$_Home) {}
  [void] Write([IRenderable]$renderable) {
  }
  [void] WriteAnsi([object]$action) {
    # Action[AnsiWriter]
  }
}

class PsRecord {
  hidden [uri] $Remote # usually a gist uri
  hidden [string] $File
  hidden [datetime] $LastWriteTime = [datetime]::Now

  PsRecord() {
    $this._init_()
  }
  PsRecord($hashtable) {
    $this.Add(@($this.ToHashtable($hashtable))); $this._init_()
  }
  PsRecord([hashtable[]]$array) {
    $this.Add($array); $this._init_()
  }
  hidden [void] _init_() {
    $this.PsObject.Methods.Add([PSScriptMethod]::new('GetCount', [ScriptBlock]::Create({ ($this | Get-Member -Type *Property).count })))
    $this.PsObject.Methods.Add([PSScriptMethod]::new('GetKeys', [ScriptBlock]::Create({ ($this | Get-Member -Type *Property).Name })))
  }
  [void] Edit() {
    $this.Set([PsRecord]::EditFile([IO.FileInfo]::new($this.File)))
    $this.Save()
  }
  [void] Add([hashtable]$table) {
    [ValidateNotNull()][hashtable]$table = $table
    $Keys = $table.Keys | Where-Object { !$this.HasProperty($_) -and ($_.GetType().FullName -eq 'System.String' -or $_.GetType().BaseType.FullName -eq 'System.ValueType') }
    foreach ($key in $Keys) {
      if ($key -notin ('File', 'Remote', 'LastWriteTime')) {
        $nval = $table[$key]; [string]$val_type_name = ($null -ne $nval) ? $nval.GetType().Name : [string]::Empty
        if ($val_type_name -eq 'ScriptBlock') {
          $this.PsObject.Properties.Add([PsScriptProperty]::new($key, $nval, [scriptblock]::Create("throw [System.Management.Automation.SetValueException]::new('$key is read-only')")))
        } else {
          $this | Add-Member -MemberType NoteProperty -Name $key -Value $nval
        }
      } else {
        $this.$key = $table[$key]
      }
    }
  }
  [void] Add([hashtable[]]$items) {
    foreach ($item in $items) { $this.Add($item) }
  }
  [void] Add([string]$key, [System.Object]$value) {
    [ValidateNotNullOrWhiteSpace()][string]$key = $key
    if (!$this.HasProperty($key)) {
      $htab = [hashtable]::new(); $htab.Add($key, $value); $this.Add($htab)
    } else {
      Write-Warning "Config.Add() Skipped $Key. Key already exists."
    }
  }
  [void] Add([List[hashtable]]$items) {
    foreach ($item in $items) { $this.Add($item) }
  }
  [void] Set([OrderedDictionary]$dict) {
    $dict.Keys.Foreach({ $this.Set($_, $dict["$_"]) });
  }
  [void] Set([hashtable]$table) {
    [ValidateNotNull()][hashtable]$table = $table
    $Keys = $table.Keys | Where-Object { $_.GetType().FullName -eq 'System.String' -or $_.GetType().BaseType.FullName -eq 'System.ValueType' } | Sort-Object -Unique
    foreach ($key in $Keys) {
      $nval = $table[$key]; [string]$val_type_name = ($null -ne $nval) ? $nval.GetType().Name : [string]::Empty
      if ($val_type_name -eq 'ScriptBlock') {
        $this.PsObject.Properties.Add([PsScriptProperty]::new($key, $nval, [scriptblock]::Create("throw [System.Management.Automation.SetValueException]::new('$key is read-only')") ))
      } else {
        $this | Add-Member -MemberType NoteProperty -Name $key -Value $nval -Force
      }
    }
  }
  [void] Set([hashtable[]]$items) {
    foreach ($item in $items) { $this.Set($item) }
  }
  [void] Set([string]$key, [System.Object]$value) {
    $htab = [hashtable]::new(); $htab.Add($key, $value)
    $this.Set($htab)
  }
  # work in progress
  static [hashtable[]] Read([string]$FilePath) {
    $cfg = $null
    return $cfg
  }
  [bool] HasProperty([object]$Name) {
    [ValidateNotNullOrWhiteSpace()][string]$Name = $($Name -as 'string')
    return $this.PsObject.Properties.Name -contains "$Name"
  }
  [void] Import([String]$FilePath) {
    Write-Host "Import records: $FilePath ..." -ForegroundColor Green
    $this.Set([PsRecord]::Read($FilePath))
    Write-Host "Import records Complete" -ForegroundColor Green
  }
  [byte[]] ToByte() {
    return $this | xconvert ToBytes
  }
  [hashtable] ToHashtable([object]$InputObject) {
    return $this.ToHashtable($InputObject, 64)
  }
  [hashtable] ToHashtable([object]$InputObject, [int] $MaxDepth) {
    # Base cases
    if ($null -eq $InputObject) { return $null }
    if ($MaxDepth -le 0) { return $InputObject }

    # Already a dictionary/hashtable — re-recurse its values
    if ($InputObject -is [System.Collections.IDictionary]) {
      $hash = @{}
      foreach ($key in $InputObject.Keys) {
        $hash[$key] = $this.ToHashtable($InputObject[$key], $MaxDepth - 1)
      }
      return $hash
    }

    # Enumerable (but not a string) — map each element
    if ($InputObject -is [System.Collections.IEnumerable] -and
      $InputObject -isnot [string]) {
      $collection = [System.Collections.Generic.List[object]]::new()
      foreach ($item in $InputObject) {
        $collection.Add($this.ToHashtable($item, $MaxDepth - 1))
      }
      # Return a typed array so PowerShell doesn't unwrap a single-element list
      return , $collection.ToArray()
    }

    # PSObject (e.g. deserialized JSON, Select-Object output, custom objects)
    if ($InputObject -is [psobject] -and
      $InputObject.PSObject.Properties.Count -gt 0) {
      $hash = @{}
      foreach ($prop in $InputObject.PSObject.Properties) {
        $hash[$prop.Name] = $this.ToHashtable($prop.Value, $MaxDepth - 1)
      }
      return $hash
    }

    # Scalar / value type — return as-is
    return $InputObject
  }
  [void] Import([uri]$raw_uri) { }
  [void] Upload() {
    if ([string]::IsNullOrWhiteSpace($this.Remote)) { throw [System.ArgumentException]::new('remote') }
  }
  [array] ToArray() {
    $array = @(); $props = $this | Get-Member -MemberType NoteProperty
    if ($null -eq $props) { return @() }
    $props.name | ForEach-Object { $array += @{ $_ = $this.$_ } }
    return $array
  }
  [string] ToJson() {
    return [string]($this | Select-Object -ExcludeProperty count | ConvertTo-Json -Depth 3)
  }
  [System.Collections.Specialized.OrderedDictionary] ToOrdered() {
    $dict = [System.Collections.Specialized.OrderedDictionary]::new(); $Keys = $this.PsObject.Properties.Where({ $_.Membertype -like "*Property" }).Name
    if ($Keys.Count -gt 0) {
      $Keys | ForEach-Object { [void]$dict.Add($_, $this."$_") }
    }
    return $dict
  }
  [string] ToString() {
    $r = $this.ToArray(); $s = ''
    $shortnr = [ScriptBlock]::Create({
        while ($str.Length -gt $MaxLength) {
          $str = $str.Substring(0, [Math]::Floor(($str.Length * 4 / 5)))
        }
        return $str
      }
    )
    if ($r.Count -gt 1) {
      $b = $r[0]; $e = $r[-1]
      $0 = $shortnr.Invoke("{'$($b.Keys)' = '$($b.values.ToString())'}", 40)
      $1 = $shortnr.Invoke("{'$($e.Keys)' = '$($e.values.ToString())'}", 40)
      $s = "@($0 ... $1)"
    } elseif ($r.count -eq 1) {
      $0 = $shortnr.Invoke("{'$($r[0].Keys)' = '$($r[0].values.ToString())'}", 40)
      $s = "@($0)"
    } else {
      $s = '@()'
    }
    return $s
  }
}

class NetRouteDiagnostics {
  [string]$ComputerName
  [string]$RemoteAddress
  [string]$ConstrainSourceAddress
  [int]$ConstrainInterfaceIndex
  [bool]$Detailed
  [bool]$RouteDiagnosticsSucceeded
  [string[]]$RouteSelectionEvents = @()
  [string[]]$SourceAddressSelectionEvents = @()
  [string[]]$DestinationAddressSelectionEvents = @()
  [string]$LogFile
  [object]$SelectedNetRoute
  [object]$SelectedSourceAddress
  [object]$OutgoingNetAdapter
  [string]$OutgoingInterfaceAlias
  [int]$OutgoingInterfaceIndex
  [string]$OutgoingInterfaceDescription
  [string[]]$ResolvedAddresses
}

class TestNetConnectionResult {
  [string]$ComputerName
  [bool]$Detailed
  [string[]]$ResolvedAddresses
  [bool]$NameResolutionSucceeded
  [string]$RemoteAddress
  [bool]$TcpTestSucceeded
  [int]$RemotePort
  [bool]$PingSucceeded
  [object]$PingReplyDetails
  [string[]]$TraceRoute
  [object[]]$DNSOnlyRecords
  [object[]]$LLMNRNetbiosRecords
  [object[]]$BasicNameResolution
  [object[]]$AllNameResolutionResults
  [bool]$IsAdmin
  [string]$NetworkIsolationContext
  [object[]]$MatchingIPsecRules
  [string]$SourceAddress
  [object]$NetRoute
  [object]$NetAdapter
  [string]$InterfaceAlias
  [int]$InterfaceIndex
  [string]$InterfaceDescription
}

class RenderOptions : PsRecord {
  [ColorSystem]$ColorSystem = [ColorSystem]::NoColors
  [bool]$Ansi = $false
  [bool]$SingleLine = $false
  [Nullable[int]]$Height = $null
  [Nullable[Justify]]$Justification = $null
  [bool]$Unicode = $true

  RenderOptions() : base() {}
  RenderOptions($options) : base($options) {}

  static [RenderOptions] Create([object]$writer, [object]$capabilities) {
    $options = [RenderOptions]::new()
    if ($null -ne $capabilities) {
      $options.ColorSystem = $capabilities.ColorSystem
      $options.Ansi = $capabilities.Ansi
    }
    return $options
  }
}

class IRenderable {
  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    $safeWidth = [Math]::Max(0, $maxWidth)
    return [Measurement]::new($safeWidth, $safeWidth)
  }

  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    return [object[]]@()
  }
}
