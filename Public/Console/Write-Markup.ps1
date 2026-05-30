function Write-Markup {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
    [string]$MarkupText,
    [switch]$NoNewLine
  )
  process {
    $markup = [Markup]::new($MarkupText)
    if ($NoNewLine) {
      [AnsiConsole]::Console.Write($markup)
    } else {
      [AnsiConsole]::Console.WriteLine($markup)
    }
  }
}
