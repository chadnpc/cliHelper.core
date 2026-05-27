function Invoke-MethodSafely {
  <#
  .SYNOPSIS
      Safely invokes a method on an object by name, returning a Result.

  .PARAMETER InputObject
      The target object.

  .PARAMETER MethodName
      Name of the method to call.

  .PARAMETER Arguments
      Array of arguments to pass.

  .EXAMPLE
      $result = [System.IO.Path]::GetFullPath | Invoke-MethodSafely -MethodName ...
      # Cleaner: $result = Invoke-MethodSafely [System.IO.File] 'ReadAllText' @('path.txt')
  #>
  [CmdletBinding()]
  [OutputType([Result])]
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [object]$InputObject,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$MethodName,

    [Parameter()]
    [object[]]$Arguments = @()
  )

  process {
    if ($null -eq $InputObject) {
      return [Result]::Err(
        [System.ArgumentNullException]::new('InputObject', 'Cannot invoke method on null.'))
    }
    try {
      # Use PSMethod.Invoke for both instance and static methods
      $value = $InputObject.$MethodName.Invoke($Arguments)
      return [Result]::Ok($value)
    } catch {
      return [Result]::Err($_.Exception)
    }
  }
}
