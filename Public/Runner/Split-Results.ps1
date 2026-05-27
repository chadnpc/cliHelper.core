function Split-Results {
  <#
  .SYNOPSIS
      Partitions a pipeline of Results into two arrays: Ok values and Err values.

  .OUTPUTS
      A hashtable with keys 'Ok' (array of unwrapped values) and 'Err' (array of errors).

  .EXAMPLE
      $parts = @(
          [Result]::Ok(1), [Result]::Err('x'), [Result]::Ok(2), [Result]::Err('y')
      ) | Split-Results

      $parts.Ok   # 1, 2
      $parts.Err  # 'x', 'y'
  #>
  [OutputType([hashtable])]
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [Result[]]$Results
  )

  begin {
    $okList = [System.Collections.Generic.List[object]]::new()
    $errList = [System.Collections.Generic.List[object]]::new()
  }
  process {
    foreach ($r in $Results) {
      if ($null -eq $r) { continue }
      if ($r.IsOk()) { $okList.Add($r.ToNullable()) }
      else { $errList.Add($r.UnwrapErr()) }
    }
  }
  end {
    return @{
      Ok  = $okList.ToArray()
      Err = $errList.ToArray()
    }
  }
}
