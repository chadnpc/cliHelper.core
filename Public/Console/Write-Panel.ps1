function Write-Panel {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Text,
    [Parameter(Position = 1)]
    [string]$Header,
    [switch]$Center
  )
  process {
    $panel = [Panel]::new([Markup]::new($Text))
    if ($Header) {
      $panel.Header = [PanelHeader]::new($Header)
    }
    $renderable = $panel
    if ($Center) {
      $renderable = [Align]::Center($panel)
    }
    [AnsiConsole]::Console.Write($renderable)
  }
}
