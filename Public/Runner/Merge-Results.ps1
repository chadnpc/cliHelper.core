function Merge-Results {
  <#
  .SYNOPSIS
      Collects an array / pipeline of Results into a single Result.

  .DESCRIPTION
      • If ALL inputs are Ok  → returns Ok(@(values))
      • If ANY input  is Err  → returns the first Err immediately (fail-fast).

      This is the PowerShell equivalent of Rust's Iterator::collect::<Result<Vec<T>,E>>().

  .EXAMPLE
      $results = 1..5 | ForEach-Object { [Result]::Ok($_ * 10) }
      $combined = $results | Merge-Results
      # Ok(@(10, 20, 30, 40, 50))

  .EXAMPLE
      @(
          [Result]::Ok(1),
          [Result]::Err('bad'),
          [Result]::Ok(3)
      ) | Merge-Results
      # Err('bad')
  #>
  [CmdletBinding()]
  [OutputType([Result])]
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [Result[]]$Results
  )

  begin {
    $values = [System.Collections.Generic.List[object]]::new()
  }
  process {
    foreach ($r in $Results) {
      if ($null -eq $r) {
        # Treat a null Result as a programming error
        $Script:_mergeFirstErr = [Result]::Err(
          [System.InvalidOperationException]::new('Merge-Results received a null Result.'))
        return   # stop processing in this pipeline segment
      }
      if ($r.IsErr()) {
        $Script:_mergeFirstErr = $r
        return
      }
      $values.Add($r.ToNullable())
    }
  }
  end {
    if ($null -ne $Script:_mergeFirstErr) {
      $err = $Script:_mergeFirstErr
      Remove-Variable _mergeFirstErr -Scope Script -ErrorAction SilentlyContinue
      return $err
    }
    return [Result]::Ok($values.ToArray())
  }
}
