using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Collections.Specialized
using namespace System.Management.Automation

class PsRecord {
  hidden [uri] $Remote # usually a gist uri
  hidden [string] $File
  hidden [datetime] $LastWriteTime = [datetime]::Now

  PsRecord() {
    $this._init_()
  }
  PsRecord([hashtable]$hashtable) {
    $this.Add(@($hashtable)); $this._init_()
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
    [ValidateNotNullOrEmpty()][hashtable]$table = $table
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
    [ValidateNotNullOrEmpty()][string]$key = $key
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
    [ValidateNotNullOrEmpty()][hashtable]$table = $table
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
    [ValidateNotNullOrEmpty()][string]$Name = $($Name -as 'string')
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
