using namespace System
using namespace System.Collections.Generic
using namespace System.Collections.Specialized
using namespace System.Management.Automation

using module .\Enums.psm1


class Activity : System.Diagnostics.Activity {
  [string]$StatusDescription
  [string]$OperationName
  [string]$TraceId

  Activity() {}
  Activity([string]$Name) : base($Name) {
    $this.OperationName = $Name
    $this.TraceId = [guid]::NewGuid().ToString()
  }

  [string] ToString() { return '[{0}] {1}' -f $this.Status, $this.DisplayName }
}


class ActivityLog {
  hidden [hashtable]$Log = @{}

  [void] Add([guid]$Id, [Activity]$Activity) {
    $this.Log[$Id] = $Activity
  }

  [Activity] Get([guid]$Id) {
    return $this.Log[$Id]
  }

  [string] ToString() {
    return ($this.Log.Keys | ForEach-Object { $_.ToString() }) -join "`n"
  }
}


class ErrorLog : PSDataCollection[ErrorRecord] {
  ErrorLog() : base() {}

  [void] Export([string]$jsonPath) {
    $this | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
  }
}


class ErrorManager {
  # Lazy-loaded on first call to avoid parse-time function evaluation
  static [PSCustomObject] $CommonExceptions = $null
  static [ExceptionType[]] $AllExptnTypes = [ErrorManager]::Get_ExceptionTypes()

  ErrorManager() {}

  static [PSCustomObject] GetCommonExceptions() {
    if ($null -eq [ErrorManager]::CommonExceptions) {
      try { [ErrorManager]::CommonExceptions = (Get-ModuleData).CommonExceptions }
      catch { [ErrorManager]::CommonExceptions = [PSCustomObject]@{} }
    }
    return [ErrorManager]::CommonExceptions
  }

  static [ExceptionType[]] Get_ExceptionTypes() {
    $commonEx = [ErrorManager]::GetCommonExceptions()
    $all = [System.Collections.Generic.List[ExceptionType]]::new()
    [appdomain]::currentdomain.GetAssemblies().GetTypes().Where({
        $_.Name -like "*Exception" -and $null -ne $_.BaseType
      }).ForEach({
        [string]$FullName = $_.FullName
        $RuntimeType = ($FullName -as [type])
        $all.Add([ExceptionType][hashtable]@{
            Name        = $_.Name
            BaseType    = $_.BaseType
            TypeName    = $FullName
            Description = $commonEx."$FullName"
            Assembly    = $_.Assembly
            IsLoaded    = [bool]$RuntimeType
            IsPublic    = $RuntimeType.IsPublic
          }
        )
      }
    )
    return $all.Where({
        $null -ne $_.IsPublic -and
        !$_.TypeName.Contains('<') -and
        !$_.TypeName.Contains('+') -and
        !$_.TypeName.Contains('>')
      }
    )
  }
}


class ErrorMetadata {
  [string]$Module
  [string]$Function
  [string]$ErrorCode
  [string]$StackTrace
  [string]$ErrorMessage
  [string]$AdditionalInfo
  [ErrorSeverity]$Severity
  [string]$User = [Environment]::UserName
  hidden [bool]$IsPrinted = $false
  [datetime]$Timestamp = [DateTime]::Now

  ErrorMetadata() {}
  ErrorMetadata([hashtable]$obj) {
    $obj.Keys.ForEach({ if ($null -ne $obj.$_) { $this.$_ = $obj.$_ } })
  }
}


class ExceptionType {
  [string]$Name
  [string]$BaseType
  [string]$TypeName
  [string]$Description
  [string]$Assembly
  [bool]$IsLoaded
  [bool]$IsPublic

  ExceptionType() {}
  ExceptionType([hashtable]$obj) {
    $obj.Keys.ForEach({
        if ($null -ne $obj.$_) { $this.$_ = $obj.$_ }
      }
    )
  }
}