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
      return [AnsiConsole]::Console.Write($markup)
    } else {
      return [AnsiConsole]::Console.WriteLine($markup)
    }
  }
}
