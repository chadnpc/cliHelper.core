
function Invoke-Safely {
  <#
  .SYNOPSIS
      Wraps a scriptblock in a try/catch and returns a Result.

  .DESCRIPTION
      The scriptblock runs with ErrorActionPreference = 'Stop' so that
      non-terminating cmdlet errors (Write-Error) are also captured —
      the most common pitfall when wrapping native PS commands.

  .PARAMETER Action
      The code to run. Its return value / pipeline output becomes Ok's value.
      If it produces multiple objects the first one is used; consider wrapping
      in @() if you need an array.

  .PARAMETER ErrorMapper
      Optional transform applied to the caught Exception before Err() wraps it.
      Defaults to the identity (raw Exception object).

  .EXAMPLE
      $result = Invoke-Safely { Get-Content 'missing.txt' }
      # Returns Err(System.Management.Automation.ItemNotFoundException)

  .EXAMPLE
      $result = Invoke-Safely { Get-Content 'missing.txt' } -ErrorMapper {
          param($e) "File read failed: $($e.Message)"
      }
      # Returns Err("File read failed: ...")
  #>
  [CmdletBinding()]
  [OutputType([Result])]
  param(
    [Parameter(Mandatory)]
    [scriptblock]$Action,

    [Parameter()]
    [scriptblock]$ErrorMapper = { param($e) $e }
  )

  # Save and restore so callers see no side-effects on the preference variable.
  $savedEAP = $ErrorActionPreference
  try {
    # 'Stop' converts non-terminating errors into terminating ones so our
    # catch block captures them — this is the single most important fix for
    # production use of try/catch around PS cmdlets.
    $ErrorActionPreference = 'Stop'
    $value = & $Action
    return [Result]::Ok($value)
  } catch {
    try {
      $mapped = & $ErrorMapper $_.Exception
    } catch {
      $mapped = $_.Exception
    }
    return [Result]::Err($mapped)
  } finally {
    $ErrorActionPreference = $savedEAP
  }
}
