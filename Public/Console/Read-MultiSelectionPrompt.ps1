function Read-MultiSelectionPrompt {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Title,
    [Parameter(Mandatory)]
    [hashtable]$Choices
  )
  process {
    $multi = [MultiSelectionPrompt]::new($Title)
    foreach ($key in $Choices.Keys) {
      $multi.AddChoice($key, $Choices[$key]) | Out-Null
    }
    return $multi.Show([AnsiConsole]::Console)
  }
}
