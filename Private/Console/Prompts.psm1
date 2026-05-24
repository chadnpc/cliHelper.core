using namespace System
using namespace System.Collections.Generic

using module .\Enums.psm1
using module .\Ansi.psm1
using module .\Colors.psm1
using module .\Rendering.psm1
using module .\Widgets.psm1
using module .\Progress.psm1

class ValidationResult {
  [bool]$Successful
  [string]$Message
  ValidationResult([bool]$success, [string]$message) {
    $this.Successful = $success
    $this.Message = $message
  }
  static [ValidationResult] Success() { return [ValidationResult]::new($true, $null) }
  static [ValidationResult] Error([string]$msg) { return [ValidationResult]::new($false, $msg) }
}

class IPrompt {
  [object] Show([object]$consoleInput) {
    return $null
  }
}

class TextPrompt : IPrompt {
  [Type]$ResultType
  [string]$Title
  [object]$DefaultValue
  [bool]$ShowDefaultValue = $true
  [bool]$IsSecret = $false
  [Nullable[char]]$Mask = '*'
  [bool]$AllowEmpty = $false
  [string]$ValidationErrorMessage = '[red]Invalid input[/]'
  [Style]$PromptStyle = [Style]::Plain
  [ScriptBlock]$Validator

  TextPrompt([Type]$type, [string]$title) {
    $this.ResultType = $type
    $this.Title = $title
  }

  [object] Show([object]$consoleInput) {
    $console = [ConsoleResolver]::ResolveConsole($consoleInput)
    $writer = [ConsoleResolver]::ResolveWriter($consoleInput)

    while ($true) {
      $this.WritePrompt($console)
      $_input = $this.ReadLine($writer)
      $writer.WriteLine()

      if ([string]::IsNullOrWhiteSpace($_input)) {
        if ($null -ne $this.DefaultValue) {
          return $this.DefaultValue
        }
        if (!$this.AllowEmpty) {
          continue
        }
        return $null
      }

      $converted = $null
      try {
        if ($this.ResultType -eq [string]) {
          $converted = $_input
        } else {
          $converted = [System.Management.Automation.LanguagePrimitives]::ConvertTo($_input, $this.ResultType)
        }
      } catch {
        $console.MarkupLine($this.ValidationErrorMessage)
        continue
      }

      if ($null -ne $this.Validator) {
        $res = $this.Validator.InvokeReturnAsIs($converted)
        if ($res -is [ValidationResult] -and !$res.Successful) {
          $console.MarkupLine($res.Message)
          continue
        } elseif ($res -is [bool] -and !$res) {
          $console.MarkupLine($this.ValidationErrorMessage)
          continue
        }
      }

      return $converted
    }

    return $null
  }

  hidden [void] WritePrompt([object]$console) {
    $sb = [Text.StringBuilder]::new()
    $sb.Append($this.Title)
    if ($this.ShowDefaultValue -and $null -ne $this.DefaultValue) {
      $sb.Append(" [green]($($this.DefaultValue))[/]")
    }
    $markup = $sb.ToString().TrimEnd()
    if (!$markup.EndsWith('?') -and !$markup.EndsWith(':')) {
      $markup += ':'
    }
    $console.Markup($markup + ' ')
  }

  hidden [string] ReadLine([AnsiWriter]$writer) {
    $input = [Text.StringBuilder]::new()
    while ($true) {
      $key = [Console]::ReadKey($true)
      if ($key.Key -eq [ConsoleKey]::Enter) {
        break
      } elseif ($key.Key -eq [ConsoleKey]::Backspace) {
        if ($input.Length -gt 0) {
          $input.Length--
          $writer.Write("`b `b", [Style]::Plain)
        }
      } elseif ($key.KeyChar -ne 0 -and (-not [char]::IsControl($key.KeyChar))) {
        $input.Append($key.KeyChar)
        if ($this.IsSecret -and $null -ne $this.Mask) {
          $writer.Write($this.Mask.ToString(), $this.PromptStyle)
        } elseif (!$this.IsSecret) {
          $writer.Write($key.KeyChar.ToString(), $this.PromptStyle)
        }
      }
    }
    return $input.ToString()
  }
}

class ConfirmationPrompt : IPrompt {
  [string]$Prompt
  [Style]$PromptStyle = [Style]::Plain
  [bool]$DefaultValue = $true
  [bool]$ShowDefaultValue = $true
  [string]$Yes = 'y'
  [string]$No = 'n'

  ConfirmationPrompt([string]$prompt) {
    $this.Prompt = $prompt
  }

  [object] Show([object]$consoleInput) {
    $console = [ConsoleResolver]::ResolveConsole($consoleInput)
    $writer = [ConsoleResolver]::ResolveWriter($consoleInput)

    while ($true) {
      $sb = [Text.StringBuilder]::new()
      $sb.Append($this.Prompt)
      if ($this.ShowDefaultValue) {
        $yesText = if ($this.DefaultValue) { $this.Yes.ToUpper() } else { $this.Yes.ToLower() }
        $noText = if (!$this.DefaultValue) { $this.No.ToUpper() } else { $this.No.ToLower() }
        $sb.Append(" [blue]($yesText/$noText)[/]")
      }
      $markup = $sb.ToString().TrimEnd()
      if (!$markup.EndsWith('?') -and !$markup.EndsWith(':')) {
        $markup += '?'
      }
      $console.Markup($markup + ' ')

      $key = [Console]::ReadKey($true)
      if ($key.Key -eq [ConsoleKey]::Enter) {
        $writer.WriteLine()
        return $this.DefaultValue
      }

      $char = $key.KeyChar.ToString()
      if ($char -eq $this.Yes -or $char -eq $this.Yes.ToLower() -or $char -eq $this.Yes.ToUpper()) {
        $console.WriteLine($this.Yes)
        return $true
      } elseif ($char -eq $this.No -or $char -eq $this.No.ToLower() -or $char -eq $this.No.ToUpper()) {
        $console.WriteLine($this.No)
        return $false
      }
      $writer.WriteLine()
      $console.MarkupLine("[red]Please enter '$($this.Yes)' or '$($this.No)'[/]")
    }

    return $null
  }
}

class SelectionChoice {
  [string]$Title
  [object]$Data
  SelectionChoice([string]$title, [object]$data) {
    $this.Title = $title
    $this.data = $data
  }
}

class SelectionPrompt : IPrompt {
  [string]$Title
  [List[SelectionChoice]]$Choices
  [int]$PageSize = 10
  [Style]$HighlightStyle = [Style]::new([Color]::Blue)
  [string]$MoreChoicesText = '(Move up and down to reveal more choices)'

  hidden [int]$_index = 0

  SelectionPrompt([string]$title) {
    $this.Title = $title
    $this.Choices = [List[SelectionChoice]]::new()
  }

  [void] AddChoice([string]$title, [object]$data) {
    $this.Choices.Add([SelectionChoice]::new($title, $data))
  }

  [object] Show([object]$consoleInput) {
    if ($null -eq $consoleInput) { throw 'Console cannot be null' }
    $writer = [ConsoleResolver]::ResolveWriter($consoleInput)
    $region = [LiveDisplayRegion]::new($writer)
    $region.Begin()

    try {
      while ($true) {
        $region.Render($this.RenderLines($writer))
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::UpArrow) {
          $this._index--
          if ($this._index -lt 0) { $this._index = $this.Choices.Count - 1 }
        } elseif ($key.Key -eq [ConsoleKey]::DownArrow) {
          $this._index++
          if ($this._index -ge $this.Choices.Count) { $this._index = 0 }
        } elseif ($key.Key -eq [ConsoleKey]::Enter) {
          if ($this.Choices.Count -gt 0) {
            return $this.Choices[$this._index].data
          }
          return $null
        }
      }
    } finally {
      $region.Complete($this.RenderFinal($writer))
    }

    return $null
  }

  hidden [string[]] RenderLines([AnsiWriter]$console) {
    $start = [Math]::Max(0, $this._index - [Math]::Floor($this.PageSize / 2))
    if ($start + $this.PageSize -gt $this.Choices.Count) {
      $start = [Math]::Max(0, $this.Choices.Count - $this.PageSize)
    }
    $end = [Math]::Min($start + $this.PageSize, $this.Choices.Count)

    $lines = [List[string]]::new()
    if ($null -ne $this.Title) {
      $lines.Add(($this.MarkupToAnsi($console, $this.Title)))
    }

    for ($i = $start; $i -lt $end; $i++) {
      $choice = $this.Choices[$i]
      $isCurrent = $i -eq $this._index
      $prefix = if ($isCurrent) { '> ' } else { '  ' }
      $style = if ($isCurrent) { $this.HighlightStyle } else { [Style]::Plain }

      $text = $prefix + $choice.Title
      $lines.Add($this.MarkupToAnsi($console, $text, $style))
    }

    if ($this.Choices.Count -gt $this.PageSize) {
      $lines.Add(($this.MarkupToAnsi($console, "[grey]$($this.MoreChoicesText)[/]")))
    }

    return $lines.ToArray()
  }

  hidden [string[]] RenderFinal([AnsiWriter]$console) {
    if ($this.Choices.Count -gt 0 -and $null -ne $this.Title) {
      $choice = $this.Choices[$this._index]
      $text = "$($this.Title) [green]$($choice.Title)[/]"
      return @($this.MarkupToAnsi($console, $text, [Style]::Plain))
    }
    return [string[]]@()
  }

  hidden [string] MarkupToAnsi([AnsiWriter]$console, [string]$text) {
    return $this.MarkupToAnsi($console, $text, [Style]::Plain)
  }

  hidden [string] MarkupToAnsi([AnsiWriter]$console, [string]$text, [Style]$overrideStyle) {
    $m = [Markup]::new($text, $overrideStyle)
    $options = [RenderOptions]::Create($console, $console.Capabilities)
    $segs = $m.Render($options, 80)

    $sb = [Text.StringBuilder]::new()
    foreach ($seg in $segs) {
      $hasColor = $console.Capabilities.Ansi -and $null -ne $seg.Style -and $seg.Style -ne [Style]::Plain
      if ($hasColor) { [void]$sb.Append("`e[" + [AnsiCodeBuilder]::GetAnsi($seg.Style, $console.Capabilities.ColorSystem) + 'm') }
      [void]$sb.Append($seg.Text)
      if ($hasColor) { [void]$sb.Append("`e[0m") }
    }
    return $sb.ToString()
  }
}

class MultiSelectionPrompt : SelectionPrompt {
  [List[object]]$SelectedItems
  [string]$InstructionsText = '(Press <space> to select, <enter> to accept)'
  [Style]$SelectedStyle = [Style]::new([Color]::Green)

  MultiSelectionPrompt([string]$title) : base($title) {
    $this.SelectedItems = [List[object]]::new()
  }

  [object] Show([object]$consoleInput) {
    if ($null -eq $consoleInput) { throw 'Console cannot be null' }
    $writer = [ConsoleResolver]::ResolveWriter($consoleInput)
    $region = [LiveDisplayRegion]::new($writer)
    $region.Begin()

    try {
      while ($true) {
        $region.Render($this.RenderLines($writer))
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::UpArrow) {
          $this._index--
          if ($this._index -lt 0) { $this._index = $this.Choices.Count - 1 }
        } elseif ($key.Key -eq [ConsoleKey]::DownArrow) {
          $this._index++
          if ($this._index -ge $this.Choices.Count) { $this._index = 0 }
        } elseif ($key.Key -eq [ConsoleKey]::Spacebar) {
          if ($this.Choices.Count -gt 0) {
            $item = $this.Choices[$this._index].data
            if ($this.SelectedItems.Contains($item)) {
              [void]$this.SelectedItems.Remove($item)
            } else {
              $this.SelectedItems.Add($item)
            }
          }
        } elseif ($key.Key -eq [ConsoleKey]::Enter) {
          return $this.SelectedItems.ToArray()
        }
      }
    } finally {
      $region.Complete($this.RenderFinal($writer))
    }

    return $null
  }

  hidden [string[]] RenderLines([AnsiWriter]$console) {
    $start = [Math]::Max(0, $this._index - [Math]::Floor($this.PageSize / 2))
    if ($start + $this.PageSize -gt $this.Choices.Count) {
      $start = [Math]::Max(0, $this.Choices.Count - $this.PageSize)
    }
    $end = [Math]::Min($start + $this.PageSize, $this.Choices.Count)

    $lines = [List[string]]::new()
    if ($null -ne $this.Title) {
      $lines.Add(($this.MarkupToAnsi($console, $this.Title)))
      $lines.Add(($this.MarkupToAnsi($console, "[grey]$($this.InstructionsText)[/]")))
    }

    for ($i = $start; $i -lt $end; $i++) {
      $choice = $this.Choices[$i]
      $isCurrent = $i -eq $this._index
      $isSelected = $this.SelectedItems.Contains($choice.data)

      $prefix = if ($isCurrent) { '> ' } else { '  ' }
      $box = if ($isSelected) { '[[X]]' } else { '[[ ]]' }
      $style = if ($isCurrent) { $this.HighlightStyle } elseif ($isSelected) { $this.SelectedStyle } else { [Style]::Plain }

      $text = "$prefix$box $($choice.Title)"
      $lines.Add($this.MarkupToAnsi($console, $text, $style))
    }

    if ($this.Choices.Count -gt $this.PageSize) {
      $lines.Add(($this.MarkupToAnsi($console, "[grey]$($this.MoreChoicesText)[/]")))
    }

    return $lines.ToArray()
  }

  hidden [string[]] RenderFinal([AnsiWriter]$console) {
    if ($null -ne $this.Title) {
      $titles = [List[string]]::new()
      foreach ($choice in $this.Choices) {
        if ($this.SelectedItems.Contains($choice.data)) {
          $titles.Add($choice.Title)
        }
      }
      $joined = $titles -join ', '
      $text = "$($this.Title) [green]$joined[/]"
      return @($this.MarkupToAnsi($console, $text))
    }
    return [string[]]@()
  }
}