using namespace System
using namespace System.Collections.Generic

using module .\Enums.psm1
using module .\Colors.psm1
using module .\Rendering.psm1

class BarChartItem {
  [string]$Label
  [double]$Value
  [Color]$Color

  BarChartItem([string]$label, [double]$value, [Color]$color) {
    $this.Label = $label
    $this.Value = $value
    $this.Color = if ($null -ne $color) { $color } else { [Color]::Default }
  }
}

class BarChart : IRenderable {
  [List[BarChartItem]]$Items = [List[BarChartItem]]::new()
  [int]$Width = 40
  [string]$ValueFormat = '0.##'

  [BarChart] AddItem([string]$label, [double]$value, [Color]$color) {
    $this.Items.Add([BarChartItem]::new($label, $value, $color))
    return $this
  }

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    return [Measurement]::new(0, [Math]::Min([Math]::Max(1, $this.Width + 20), $maxWidth))
  }

  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    if ($this.Items.Count -eq 0) { return [Segment[]]@([Segment]::new('(empty chart)')) }
    $max = ($this.Items | Measure-Object -Property Value -Maximum).Maximum
    if ($max -le 0) { $max = 1 }
    $labelWidth = ($this.Items | ForEach-Object { $_.Label.Length } | Measure-Object -Maximum).Maximum
    $barWidth = [Math]::Max(1, [Math]::Min($this.Width, $maxWidth - $labelWidth - 10))
    $segments = [List[Segment]]::new()
    for ($i = 0; $i -lt $this.Items.Count; $i++) {
      $it = $this.Items[$i]
      $cells = [Math]::Round(($it.Value / $max) * $barWidth)
      $bar = ('█' * [Math]::Max(0, $cells)).PadRight($barWidth, ' ')
      $line = ('{0,-' + $labelWidth + '} {1} {2}') -f $it.Label, $bar, $it.Value.ToString($this.ValueFormat)
      $style = [Style]::new($it.Color)
      $segments.Add([Segment]::new($line, $style))
      if ($i -lt $this.Items.Count - 1) { $segments.Add([Segment]::LineBreak) }
    }
    return $segments.ToArray()
  }
}

class BreakdownChartItem {
  [string]$Label
  [double]$Value
  [Color]$Color
  BreakdownChartItem([string]$label, [double]$value, [Color]$color) {
    $this.Label = $label
    $this.Value = $value
    $this.Color = if ($null -ne $color) { $color } else { [Color]::Default }
  }
}

class BreakdownChart : IRenderable {
  [List[BreakdownChartItem]]$Items = [List[BreakdownChartItem]]::new()

  [BreakdownChart] AddItem([string]$label, [double]$value, [Color]$color) {
    $this.Items.Add([BreakdownChartItem]::new($label, $value, $color))
    return $this
  }

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) { return [Measurement]::new(0, $maxWidth) }

  [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
    if ($this.Items.Count -eq 0) { return [Segment[]]@([Segment]::new('(empty breakdown)')) }
    $total = ($this.Items | Measure-Object -Property Value -Sum).Sum
    if ($total -le 0) { $total = 1 }
    $segments = [List[Segment]]::new()
    for ($i = 0; $i -lt $this.Items.Count; $i++) {
      $it = $this.Items[$i]
      $percent = ($it.Value / $total) * 100
      $line = '{0}: {1:0.##}% ({2:0.##})' -f $it.Label, $percent, $it.Value
      $segments.Add([Segment]::new($line, [Style]::new($it.Color)))
      if ($i -lt $this.Items.Count - 1) { $segments.Add([Segment]::LineBreak) }
    }
    return $segments.ToArray()
  }
}
