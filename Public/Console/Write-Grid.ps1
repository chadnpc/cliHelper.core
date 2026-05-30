function Write-Grid {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [int]$Columns,
    [Parameter(Mandatory, Position = 1)]
    [Array]$Rows
  )
  process {
    $grid = [Grid]::new()
    for ($i = 0; $i -lt $Columns; $i++) {
      $grid.AddColumn() | Out-Null
    }
    foreach ($row in $Rows) {
      if ($row -is [Array]) {
        $markupRow = [System.Collections.Generic.List[IRenderable]]::new()
        foreach ($item in $row) {
          if ($item -is [IRenderable]) {
            $markupRow.Add($item)
          } else {
            $markupRow.Add([Markup]::new([string]$item))
          }
        }
        [void]$grid.AddRow($markupRow.ToArray())
      }
    }
    [AnsiConsole]::Console.Write($grid)
  }
}
