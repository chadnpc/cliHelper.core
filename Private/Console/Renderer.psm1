using namespace System
using namespace System.Collections.Generic
using namespace System.Text
using module .\Enums.psm1
using module .\Colors.psm1
using module .\Rendering.psm1
using module .\Ansi.psm1

class ConsoleRenderer {
  static [void] Render([IAnsiConsole]$console, [IRenderable]$renderable) {
    if ($null -eq $renderable) { return }

    $writer = [AnsiWriter]($console.GetWriter())
    if ($null -eq $writer) {
      Write-Debug "Console does not have ANSI output writer."
      return
    }

    $consoleProfile = $console.Profile
    if ($null -eq $consoleProfile) {
      Write-Debug "Console does not have a valid profile."
      return
    }

    $renderOptions = $consoleProfile.CreateRenderOptions()
    if ($null -eq $renderOptions) {
      Write-Debug "Failed to create render options."
      return
    }

    $maxWidth = $consoleProfile.GetWidth()

    foreach ($segment in $renderable.Render($renderOptions, $maxWidth)) {
      if ($null -eq $segment) { continue }

      if ($segment.IsControlCode) {
        $writer.Write($segment.Text)
        continue
      }

      # Handle line breaks within segments
      if ($segment.Text.Contains("`n")) {
        $parts = $segment.Text.Split("`n")
        for ($i = 0; $i -lt $parts.Length; $i++) {
          if ($parts[$i].Length -gt 0) {
            $writer.Write($parts[$i], $segment.Style)
          }

          if ($i -lt $parts.Length - 1) {
            $writer.WriteLine()
          }
        }
      } else {
        $writer.Write($segment.Text, $segment.Style)
      }
    }
  }
}
