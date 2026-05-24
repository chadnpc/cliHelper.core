using namespace System
using namespace System.Collections.Generic
using namespace System.Linq

using module .\Enums.psm1
using module .\Rendering.psm1
using module .\Widgets.psm1
using module .\Tables.psm1
using module .\TableRenderer.psm1
using module .\Table.psm1

class Rows : IRenderable {
    hidden [List[IRenderable]] $_children
    [bool]$Expand

    Rows([IEnumerable[IRenderable]]$items) {
        $this._children = [List[IRenderable]]::new($items)
        $this.Expand = $false
    }

    Rows([IRenderable[]]$items) {
        $this._children = [List[IRenderable]]::new($items)
        $this.Expand = $false
    }

    [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
        if ($this.Expand) { return [Measurement]::new($maxWidth, $maxWidth) }
        if ($this._children.Count -eq 0) { return [Measurement]::new(0, 0) }

        $measurements = [List[Measurement]]::new()
        foreach ($c in $this._children) { $measurements.Add($c.Measure($options, $maxWidth)) }

        $min = 0; $max = 0
        foreach ($m in $measurements) {
            if ($m.Min -gt $min) { $min = $m.Min }
            if ($m.Max -gt $max) { $max = $m.Max }
        }
        return [Measurement]::new($min, $max)
    }

    [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
        $result = [List[Segment]]::new()
        foreach ($child in $this._children) {
            $rendered = $child.Render($options, $maxWidth)
            $result.AddRange($rendered)
            if ($rendered.Count -gt 0 -and !$rendered[$rendered.Count - 1].IsLineBreak) {
                $result.Add([Segment]::LineBreak)
            }
        }
        return $result.ToArray()
    }
}

class Columns : IRenderable {
    hidden [List[IRenderable]] $_items
    [Padding]$Padding
    [bool]$Expand

    Columns([IEnumerable[IRenderable]]$items) {
        $this._items = [List[IRenderable]]::new($items)
        $this.Padding = [Padding]::new(0, 0, 1, 0)
        $this.Expand = $true
    }

    [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
        if ($this._items.Count -eq 0) { return [Measurement]::new(0, 0) }
        $maxPadding = [Math]::Max($this.Padding.Left, $this.Padding.Right)

        $itemWidths = [List[int]]::new()
        foreach ($item in $this._items) { $itemWidths.Add($item.Measure($options, $maxWidth).Max) }

        $columnCount = $this.CalculateColumnCount($maxWidth, $itemWidths.ToArray(), $this._items.Count, $maxPadding)
        if ($columnCount -le 0) { return [Measurement]::new($maxWidth, $maxWidth) }

        $rows = [Math]::Ceiling($this._items.Count / $columnCount)
        $greatestWidth = 0
        for ($r = 0; $r -lt $rows; $r++) {
            $start = $r * $columnCount
            $end = [Math]::Min($start + $columnCount, $this._items.Count)
            $rowWidth = 0
            for ($i = $start; $i -lt $end; $i++) { $rowWidth += $itemWidths[$i] }
            $rowWidth += ($maxPadding * ($end - $start - 1))
            if ($rowWidth -gt $greatestWidth) { $greatestWidth = $rowWidth }
        }

        return [Measurement]::new($greatestWidth, $greatestWidth)
    }

    [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
        if ($this._items.Count -eq 0) { return [object[]]@() }
        $maxPadding = [Math]::Max($this.Padding.Left, $this.Padding.Right)

        $itemWidths = [List[int]]::new()
        foreach ($item in $this._items) { $itemWidths.Add($item.Measure($options, $maxWidth).Max) }

        $columnCount = $this.CalculateColumnCount($maxWidth, $itemWidths.ToArray(), $this._items.Count, $maxPadding)
        if ($columnCount -le 0) { $columnCount = 1 }

        $table = [Table]::new()
        $table.Border = [NoTableBorder]::new()
        $table.ShowHeaders = $false
        $table.PadRightCell = $false
        if ($this.Expand) { $table.Expand = $true }

        for ($i = 0; $i -lt $columnCount; $i++) {
            $col = [TableColumn]::new("")
            $col.Padding = $this.Padding
            $col.NoWrap = $true
            $table.AddColumn($col)
        }

        for ($start = 0; $start -lt $this._items.Count; $start += $columnCount) {
            $rowItems = [List[IRenderable]]::new()
            for ($i = $start; $i -lt [Math]::Min($start + $columnCount, $this._items.Count); $i++) {
                $rowItems.Add($this._items[$i])
            }
            # Fill remaining columns with empty text if any
            while ($rowItems.Count -lt $columnCount) { $rowItems.Add([Text]::new("")) }
            $table.AddRow($rowItems)
        }

        return $table.Render($options, $maxWidth)
    }

    hidden [int] CalculateColumnCount([int]$maxWidth, [int[]]$itemWidths, [int]$columnCount, [int]$padding) {
        $currentCount = $columnCount
        while ($currentCount -gt 1) {
            $widths = @{}
            $exceeded = $false
            for ($i = 0; $i -lt $itemWidths.Length; $i++) {
                $colIdx = $i % $currentCount
                if (!$widths.ContainsKey($colIdx)) { $widths[$colIdx] = 0 }
                $widths[$colIdx] = [Math]::Max($widths[$colIdx], $itemWidths[$i])

                $total = 0
                foreach ($w in $widths.Values) { $total += $w }
                $total += ($padding * ($widths.Count - 1))
                if ($total -gt $maxWidth) {
                    $currentCount = $widths.Count - 1
                    $exceeded = $true
                    break
                }
            }
            if (!$exceeded) { break }
        }
        return $currentCount
    }
}

class GridColumn {
    [Nullable[int]]$Width
    [bool]$NoWrap
    [Padding]$Padding
    [Nullable[Justify]]$Alignment
    [bool]$HasExplicitPadding

    GridColumn() {
        $this.Padding = [Padding]::new(0, 0, 2, 0)
        $this.NoWrap = $false
        $this.HasExplicitPadding = $false
    }

    [GridColumn] PadRight([int]$padding) {
        $this.Padding = [Padding]::new($this.Padding.Left, $this.Padding.Top, $padding, $this.Padding.Bottom)
        $this.HasExplicitPadding = $true
        return $this
    }

    [GridColumn] NoWrap() {
        $this.NoWrap = $true
        return $this
    }
}

class Grid : IRenderable {
    hidden [List[GridColumn]] $_columns
    hidden [List[List[IRenderable]]] $_rows
    [bool]$Expand
    [Nullable[int]]$Width

    Grid() {
        $this._columns = [List[GridColumn]]::new()
        $this._rows = [List[List[IRenderable]]]::new()
        $this.Expand = $false
    }

    [Grid] AddColumn() {
        $this._columns.Add([GridColumn]::new())
        return $this
    }

    [Grid] AddColumn([GridColumn]$column) {
        if ($this._rows.Count -gt 0) { throw [InvalidOperationException]::new("Cannot add columns after rows.") }
        $this._columns.Add($column)
        return $this
    }

    [Grid] AddRow([IRenderable[]]$items) {
        if ($items.Length -gt $this._columns.Count) { throw [InvalidOperationException]::new("Row has more items than columns.") }
        $this._rows.Add([List[IRenderable]]::new($items))
        return $this
    }

    [Grid] AddRow([object[]]$items) {
        $list = [List[IRenderable]]::new()
        foreach ($item in $items) {
            if ($item -is [IRenderable]) {
                $list.Add([IRenderable]$item)
            } else {
                $text = if ($null -eq $item) { [string]::Empty } else { [string]$item }
                $list.Add([Markup]::new($text))
            }
        }
        return $this.AddRow($list.ToArray())
    }

    [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
        $table = $this.BuildTable()
        return $table.Measure($options, $maxWidth)
    }

    [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
        $table = $this.BuildTable()
        return $table.Render($options, $maxWidth)
    }

    hidden [Table] BuildTable() {
        $table = [Table]::new()
        $table.Border = [NoTableBorder]::new()
        $table.ShowHeaders = $false
        $table.IsGrid = $true
        $table.Width = $this.Width
        $table.Expand = $this.Expand

        foreach ($col in $this._columns) {
            $tc = [TableColumn]::new("")
            $tc.Width = $col.Width
            $tc.NoWrap = $col.NoWrap
            $tc.Padding = $col.Padding
            $tc.Alignment = $col.Alignment
            $table.AddColumn($tc)
        }

        foreach ($row in $this._rows) {
            $table.AddRow($row)
        }

        return $table
    }
}


