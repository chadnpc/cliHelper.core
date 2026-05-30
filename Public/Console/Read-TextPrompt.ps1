function Read-TextPrompt {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Prompt,
    [Parameter()]
    [string]$DefaultValue
  )
  process {
    $textPrompt = [TextPrompt]::new([string], $Prompt)
    if ($DefaultValue) {
      $textPrompt.DefaultValue = $DefaultValue
    }
    return $textPrompt.Show([AnsiConsole]::Console)
  }
}
