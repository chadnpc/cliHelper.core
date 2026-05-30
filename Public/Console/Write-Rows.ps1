function Write-Rows {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string[]]$Items
  )
  process {
    $markupItems = [System.Collections.Generic.List[IRenderable]]::new()
    foreach ($item in $Items) {
      $markupItems.Add([Markup]::new($item))
    }
    $rows = [Rows]::new($markupItems.ToArray())
    [AnsiConsole]::Console.Write($rows)
  }
}
