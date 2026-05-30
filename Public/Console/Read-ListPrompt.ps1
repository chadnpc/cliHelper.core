function Read-ListPrompt {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Title,
    [Parameter(Mandatory, Position = 1)]
    [string[]]$Items
  )
  process {
    $prompt = [ListPrompt]::new($Title)
    $prompt.AddItems($Items)
    return $prompt.Show([AnsiConsole]::Console)
  }
}
