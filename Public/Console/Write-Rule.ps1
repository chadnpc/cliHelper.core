function Write-Rule {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $false, Position = 0)]
    [string]$Title = ""
  )
  process {
    $rule = [Rule]::new($Title)
    return [AnsiConsole]::Console.Write($rule)
  }
}
