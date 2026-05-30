function Write-Table {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string[]]$Columns,
    [Parameter(Mandatory, Position = 1)]
    [Array]$Rows
  )
  process {
    $table = [Table]::new()
    foreach ($col in $Columns) {
      [void]$table.AddColumn([TableColumn]::new($col))
    }
    foreach ($row in $Rows) {
      if ($row -is [Array]) {
        [void]$table.AddRow([string[]]$row)
      }
    }
    return [AnsiConsole]::Console.Write($table)
  }
}
