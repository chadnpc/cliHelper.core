function Show-Progress {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Activity,
    [Parameter(Mandatory, Position = 1)]
    [scriptblock]$Action
  )
  process {
    $progress = [Progress]::new([AnsiConsole]::Console)
    $progress.RefreshRateMs = 80
    $progress.Start([Action[ProgressContext]] {
        param([ProgressContext]$ctx)
        & $Action $ctx
      }
    )
  }
}
