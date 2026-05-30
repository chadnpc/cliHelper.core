function Write-Figlet {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Text,
    [Parameter()]
    [string]$Font = "DEFAULT_3D"
  )
  process {
    $fig = [FigletText]::new([FigletFont]$Font, $Text)
    return [AnsiConsole]::Console.Write($fig)
  }
}
