function Show-Status {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$StatusText,
    [Parameter(Mandatory, Position = 1)]
    [scriptblock]$Action
  )
  process {
    $status = [Status]::new([AnsiConsole]::Console.GetWriter())
    $status.RefreshRateMs = 80
    $status.Start($StatusText, [Action[StatusContext]] {
      param([StatusContext]$ctx)
      & $Action $ctx
    })
  }
}
