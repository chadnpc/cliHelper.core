function Read-ConfirmPrompt {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Prompt,
    [Parameter()]
    [bool]$DefaultValue = $false
  )
  process {
    $confirm = [ConfirmationPrompt]::new($Prompt)
    $confirm.DefaultValue = $DefaultValue
    return $confirm.Show([AnsiConsole]::Console)
  }
}
