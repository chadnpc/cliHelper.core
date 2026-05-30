function Read-SelectionPrompt {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Title,
    [Parameter(Mandatory)]
    [hashtable]$Choices
  )
  process {
    $selection = [SelectionPrompt]::new($Title)
    foreach ($key in $Choices.Keys) {
      $selection.AddChoice($key, $Choices[$key]) | Out-Null
    }
    return $selection.Show([AnsiConsole]::Console)
  }
}
