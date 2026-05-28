using namespace System
using namespace System.Collections.Generic
using namespace System.Text

using module .\Ansi.psm1
using module .\Colors.psm1
using module ..\Enums.psm1
using module ..\Abstracts.psm1
using module .\Progress.psm1
using module .\Prompts.psm1
using module .\Rendering.psm1
using module .\Widgets.psm1

class ListPromptConstants {
  static [string]$Instructions = '(Type to filter, arrows to move, enter to select)'
  static [string]$NoMatches = 'No matches'
  static [int]$DefaultPageSize = 10
}

class ListPromptItem {
  [string]$Title
  [object]$Data
  [bool]$Selected = $false

  ListPromptItem([string]$title, [object]$data) {
    $this.Title = $title
    $this.Data = $data
  }
}

class ListPromptKeyInput {
  [bool]$Accepted
  [bool]$Cancelled
  [string]$Character
  [ConsoleKey]$Key

  ListPromptKeyInput([ConsoleKey]$key, [string]$character, [bool]$accepted, [bool]$cancelled) {
    $this.Key = $key
    $this.Character = $character
    $this.Accepted = $accepted
    $this.Cancelled = $cancelled
  }
}

class ListPromptState {
  [List[ListPromptItem]]$Items
  [List[int]]$FilteredIndexes
  [string]$SearchFilter = ''
  [int]$SelectedFilteredIndex = 0
  [int]$PageSize = 10

  ListPromptState() {
    $this.Items = [List[ListPromptItem]]::new()
    $this.FilteredIndexes = [List[int]]::new()
    $this.ApplyFilter()
  }

  ListPromptState([List[ListPromptItem]]$items, [int]$pageSize) {
    $this.Items = ($null -ne $items) ? $items : [List[ListPromptItem]]::new()
    $this.PageSize = [Math]::Max(1, $pageSize)
    $this.FilteredIndexes = [List[int]]::new()
    $this.ApplyFilter()
  }

  [void] ApplyFilter() {
    $this.FilteredIndexes.Clear()
    for ($i = 0; $i -lt $this.Items.Count; $i++) {
      if ([string]::IsNullOrEmpty($this.SearchFilter) -or
        $this.Items[$i].Title.IndexOf($this.SearchFilter, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $this.FilteredIndexes.Add($i)
      }
    }

    if ($this.FilteredIndexes.Count -eq 0) {
      $this.SelectedFilteredIndex = 0
    } elseif ($this.SelectedFilteredIndex -ge $this.FilteredIndexes.Count) {
      $this.SelectedFilteredIndex = $this.FilteredIndexes.Count - 1
    } elseif ($this.SelectedFilteredIndex -lt 0) {
      $this.SelectedFilteredIndex = 0
    }
  }

  [void] SetFilter([string]$filter) {
    $this.SearchFilter = ($null -ne $filter) ? $filter : ''
    $this.SelectedFilteredIndex = 0
    $this.ApplyFilter()
  }

  [void] AppendFilter([char]$character) {
    if ([char]::IsControl($character)) { return }
    $this.SearchFilter += $character
    $this.ApplyFilter()
  }

  [void] BackspaceFilter() {
    if ($this.SearchFilter.Length -gt 0) {
      $this.SearchFilter = $this.SearchFilter.Substring(0, $this.SearchFilter.Length - 1)
      $this.ApplyFilter()
    }
  }

  [void] MoveNext() {
    if ($this.FilteredIndexes.Count -eq 0) { return }
    $this.SelectedFilteredIndex = ($this.SelectedFilteredIndex + 1) % $this.FilteredIndexes.Count
  }

  [void] MovePrevious() {
    if ($this.FilteredIndexes.Count -eq 0) { return }
    $this.SelectedFilteredIndex--
    if ($this.SelectedFilteredIndex -lt 0) { $this.SelectedFilteredIndex = $this.FilteredIndexes.Count - 1 }
  }

  [ListPromptItem] Current() {
    if ($this.FilteredIndexes.Count -eq 0) { return $null }
    return $this.Items[$this.FilteredIndexes[$this.SelectedFilteredIndex]]
  }

  [int] CurrentIndex() {
    if ($this.FilteredIndexes.Count -eq 0) { return -1 }
    return $this.FilteredIndexes[$this.SelectedFilteredIndex]
  }

  [int] PageStart() {
    if ($this.FilteredIndexes.Count -eq 0) { return 0 }
    $start = [Math]::Max(0, $this.SelectedFilteredIndex - [Math]::Floor($this.PageSize / 2))
    if ($start + $this.PageSize -gt $this.FilteredIndexes.Count) {
      $start = [Math]::Max(0, $this.FilteredIndexes.Count - $this.PageSize)
    }
    return $start
  }
}

class ListPromptTree {
  [ListPromptState]$State

  ListPromptTree([ListPromptState]$state) {
    $this.State = $state
  }

  [List[ListPromptItem]] GetVisibleItems() {
    $items = [List[ListPromptItem]]::new()
    $start = $this.State.PageStart()
    $end = [Math]::Min($start + $this.State.PageSize, $this.State.FilteredIndexes.Count)
    for ($i = $start; $i -lt $end; $i++) {
      $items.Add($this.State.Items[$this.State.FilteredIndexes[$i]])
    }
    return $items
  }
}

class ListPromptRenderHoo {
  [string] Invoke([string]$text) {
    return $text
  }
}

class ListPrompt : IPrompt {
  [string]$Title
  [List[ListPromptItem]]$Items
  [string]$SearchFilter = ''
  [int]$PageSize = 10
  [Style]$HighlightStyle = [Style]::new([Color]::Blue)
  [Style]$FilterStyle = [Style]::new([Color]::Yellow)
  [Style]$MutedStyle = [Style]::new([Color]::FromName('Grey58'))
  [bool]$ShowInstructions = $true

  hidden [ListPromptState]$_state

  ListPrompt() {
    $this.Initialize($null)
  }

  ListPrompt([string]$title) {
    $this.Initialize($title)
  }

  hidden [void] Initialize([string]$title) {
    $this.Title = $title
    $this.Items = [List[ListPromptItem]]::new()
    $this.PageSize = [ListPromptConstants]::DefaultPageSize
  }

  [void] AddItem([string]$title) {
    $this.AddItem($title, $title)
  }

  [void] AddItem([string]$title, [object]$data) {
    $this.Items.Add([ListPromptItem]::new($title, $data))
  }

  [void] AddItems([string[]]$items) {
    foreach ($item in $items) {
      $this.AddItem($item, $item)
    }
  }

  [object] Show([object]$consoleInput) {
    if ($null -eq $consoleInput) { throw 'Console cannot be null' }
    $writer = [ConsoleResolver]::ResolveWriter($consoleInput)
    $this._state = [ListPromptState]::new($this.Items, $this.PageSize)
    $this._state.SetFilter($this.SearchFilter)
    $region = [LiveDisplayRegion]::new($writer)
    $region.Begin()

    try {
      while ($true) {
        $region.Render($this.RenderLines($writer))
        $input = $this.ReadInput()

        if ($input.Accepted) {
          $current = $this._state.Current()
          return ($null -ne $current) ? $current.Data : $null
        }

        if ($input.Cancelled) {
          return $null
        }

        switch ($input.Key) {
          ([ConsoleKey]::UpArrow) { $this._state.MovePrevious(); break }
          ([ConsoleKey]::DownArrow) { $this._state.MoveNext(); break }
          ([ConsoleKey]::Backspace) { $this._state.BackspaceFilter(); break }
          default {
            if (![string]::IsNullOrEmpty($input.Character)) {
              $this._state.AppendFilter($input.Character[0])
            }
          }
        }
      }
    } finally {
      $region.Complete($this.RenderFinal($writer))
    }

    return $null
  }

  [string[]] Preview() {
    $this._state = [ListPromptState]::new($this.Items, $this.PageSize)
    $this._state.SetFilter($this.SearchFilter)
    $writer = [AnsiWriter]::new([System.IO.StringWriter]::new())
    $writer.Capabilities.Ansi = $false
    return $this.RenderLines($writer)
  }

  hidden [ListPromptKeyInput] ReadInput() {
    $key = [Console]::ReadKey($true)
    $accepted = $key.Key -eq [ConsoleKey]::Enter
    $cancelled = $key.Key -eq [ConsoleKey]::Escape
    $character = if ($key.KeyChar -ne 0 -and -not [char]::IsControl($key.KeyChar)) { $key.KeyChar.ToString() } else { '' }
    return [ListPromptKeyInput]::new($key.Key, $character, $accepted, $cancelled)
  }

  hidden [string[]] RenderLines([AnsiWriter]$writer) {
    if ($null -eq $this._state) {
      $this._state = [ListPromptState]::new($this.Items, $this.PageSize)
      $this._state.SetFilter($this.SearchFilter)
    }

    $lines = [List[string]]::new()
    if (![string]::IsNullOrWhiteSpace($this.Title)) {
      $lines.Add($this.MarkupToAnsi($writer, $this.Title, [Style]::Plain))
    }

    $filterText = if ([string]::IsNullOrEmpty($this._state.SearchFilter)) { '' } else { $this._state.SearchFilter }
    $lines.Add($this.MarkupToAnsi($writer, "Filter: $filterText", $this.FilterStyle))

    if ($this.ShowInstructions) {
      $lines.Add($this.MarkupToAnsi($writer, [ListPromptConstants]::Instructions, $this.MutedStyle))
    }

    if ($this._state.FilteredIndexes.Count -eq 0) {
      $lines.Add($this.MarkupToAnsi($writer, [ListPromptConstants]::NoMatches, $this.MutedStyle))
      return $lines.ToArray()
    }

    $start = $this._state.PageStart()
    $end = [Math]::Min($start + $this._state.PageSize, $this._state.FilteredIndexes.Count)
    for ($i = $start; $i -lt $end; $i++) {
      $itemIndex = $this._state.FilteredIndexes[$i]
      $item = $this._state.Items[$itemIndex]
      $isCurrent = $i -eq $this._state.SelectedFilteredIndex
      $prefix = if ($isCurrent) { '> ' } else { '  ' }
      $style = if ($isCurrent) { $this.HighlightStyle } else { [Style]::Plain }
      $displayTitle = $this.HighlightFilter($item.Title)
      $lines.Add($this.MarkupToAnsi($writer, $prefix + $displayTitle, $style))
    }

    return $lines.ToArray()
  }

  hidden [string[]] RenderFinal([AnsiWriter]$writer) {
    if ($null -eq $this._state) { return [string[]]@() }
    $current = $this._state.Current()
    if ($null -eq $current) { return [string[]]@() }
    $text = if ([string]::IsNullOrWhiteSpace($this.Title)) { $current.Title } else { "$($this.Title) [green]$($current.Title)[/]" }
    return @($this.MarkupToAnsi($writer, $text, [Style]::Plain))
  }

  hidden [string] HighlightFilter([string]$title) {
    if ([string]::IsNullOrEmpty($this._state.SearchFilter)) {
      return [AnsiMarkup]::Escape($title)
    }

    return [AnsiMarkup]::Highlight([AnsiMarkup]::Escape($title), $this._state.SearchFilter, $this.FilterStyle)
  }

  hidden [string] MarkupToAnsi([AnsiWriter]$writer, [string]$text, [Style]$style) {
    $markup = [Markup]::new($text, $style)
    $options = [RenderOptions]::Create($writer, $writer.Capabilities)
    $segments = $markup.Render($options, 120)
    $builder = [StringBuilder]::new()

    foreach ($segment in $segments) {
      $hasStyle = $writer.Capabilities.Ansi -and $null -ne $segment.Style -and $segment.Style.ToMarkup() -ne [Style]::Plain.ToMarkup()
      if ($hasStyle) {
        [void]$builder.Append("`e[" + [AnsiCodeBuilder]::GetAnsi($segment.Style, $writer.Capabilities.ColorSystem) + 'm')
      }
      [void]$builder.Append($segment.Text)
      if ($hasStyle) {
        [void]$builder.Append("`e[0m")
      }
    }

    return $builder.ToString()
  }
}
