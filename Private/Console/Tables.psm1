using namespace System
using namespace System.Collections.Generic
using namespace System.Linq

using module ..\Enums.psm1
using module ..\Abstracts.psm1
using module .\Rendering.psm1
using module .\Widgets.psm1
using module .\Boxes.psm1

class TableCell : IRenderable {
    [IRenderable]$Content
    [int]$ColumnSpan

    TableCell([IRenderable]$content) {
        $this.Content = $content
        $this.ColumnSpan = 1
    }

    [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
        return $this.Content.Measure($options, $maxWidth)
    }

    [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
        return $this.Content.Render($options, $maxWidth)
    }
}

class TableColumn {
    [IRenderable]$Header
    [IRenderable]$Footer
    [Nullable[int]]$Width
    [Padding]$Padding
    [bool]$NoWrap
    [Nullable[Justify]]$Alignment

    TableColumn([string]$header) {
        $this.Header = [Markup]::new($header)
        $this.Padding = [Padding]::new(1, 1, 0, 0)
        $this.NoWrap = $false
    }

    TableColumn([IRenderable]$header) {
        $this.Header = $header
        $this.Padding = [Padding]::new(1, 1, 0, 0)
        $this.NoWrap = $false
    }
}

class TableRow {
    [List[IRenderable]]$Items
    [bool]$IsHeader
    [bool]$IsFooter

    TableRow([IEnumerable[IRenderable]]$items) {
        $this.Items = [List[IRenderable]]::new($items)
        $this.IsHeader = $false
        $this.IsFooter = $false
    }

    static [TableRow] Header([IEnumerable[IRenderable]]$items) {
        $row = [TableRow]::new($items)
        $row.IsHeader = $true
        return $row
    }

    static [TableRow] Footer([IEnumerable[IRenderable]]$items) {
        $row = [TableRow]::new($items)
        $row.IsFooter = $true
        return $row
    }
}

class TableRowCollection : System.Collections.IEnumerable {
    hidden [List[TableRow]]$_list
    hidden [object]$_table

    TableRowCollection([object]$table) {
        $this._list = [List[TableRow]]::new()
        $this._table = $table
    }

    [int] get_Count() { return $this._list.Count }

    [void] Add([TableRow]$row) {
        $this._list.Add($row)
    }

    [void] Insert([int]$index, [TableRow]$row) {
        $this._list.Insert($index, $row)
    }

    [void] RemoveAt([int]$index) {
        $this._list.RemoveAt($index)
    }

    [System.Collections.IEnumerator] GetEnumerator() {
        return $this._list.GetEnumerator()
    }
}

class TableTitle {
    [string]$Text
    [Style]$Style

    TableTitle([string]$text) {
        $this.Text = $text
        $this.Style = [Style]::Plain
    }
    TableTitle([string]$text, [Style]$style) {
        $this.Text = $text
        $this.Style = if ($null -ne $style) { $style } else { [Style]::Plain }
    }
}

class TableBorder {
    [bool] get_Visible() { return $true }
    [bool] get_UsePadding() { return $true }
    [bool] get_SupportsRowSeparator() { return $false }

    static [TableBorder] get_None() { return [NoTableBorder]::new() }
    static [TableBorder] get_Ascii() { return [AsciiTableBorder]::new() }
    static [TableBorder] get_Square() { return [SquareTableBorder]::new() }
    static [TableBorder] get_Rounded() { return [RoundedTableBorder]::new() }
    static [TableBorder] get_Heavy() { return [HeavyTableBorder]::new() }
    static [TableBorder] get_Double() { return [DoubleTableBorder]::new() }

    [string] GetPart([TableBorderPart]$part) { return "" }

    [string] GetColumnRow([TablePart]$part, [List[int]]$widths, [List[TableColumn]]$columns) {
        if (!$this.Visible) { return "" }
        $parts = $this.GetTableParts($part)
        $left = $parts[0]; $center = $parts[1]; $separator = $parts[2]; $right = $parts[3]

        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.Append($left)
        for ($i=0; $i -lt $widths.Count; $i++) {
            $w = $widths[$i]
            $pad = if ($this.UsePadding) { $columns[$i].Padding.GetLeftSafe() + $columns[$i].Padding.GetRightSafe() } else { 0 }
            $w += $pad
            for ($j=0; $j -lt $w; $j++) { [void]$sb.Append($center) }
            if ($i -lt ($widths.Count - 1)) { [void]$sb.Append($separator) }
        }
        [void]$sb.Append($right)
        return $sb.ToString()
    }

    [string[]] GetTableParts([TablePart]$part) {
        switch ($part) {
            ([TablePart]::Top) { return @($this.GetPart([TableBorderPart]::HeaderTopLeft), $this.GetPart([TableBorderPart]::HeaderTop), $this.GetPart([TableBorderPart]::HeaderTopSeparator), $this.GetPart([TableBorderPart]::HeaderTopRight)) }
            ([TablePart]::HeaderSeparator) { return @($this.GetPart([TableBorderPart]::HeaderBottomLeft), $this.GetPart([TableBorderPart]::HeaderBottom), $this.GetPart([TableBorderPart]::HeaderBottomSeparator), $this.GetPart([TableBorderPart]::HeaderBottomRight)) }
            ([TablePart]::RowSeparator) { return @($this.GetPart([TableBorderPart]::RowLeft), $this.GetPart([TableBorderPart]::RowCenter), $this.GetPart([TableBorderPart]::RowSeparator), $this.GetPart([TableBorderPart]::RowRight)) }
            ([TablePart]::FooterSeparator) { return @($this.GetPart([TableBorderPart]::FooterTopLeft), $this.GetPart([TableBorderPart]::FooterTop), $this.GetPart([TableBorderPart]::FooterTopSeparator), $this.GetPart([TableBorderPart]::FooterTopRight)) }
            ([TablePart]::Bottom) { return @($this.GetPart([TableBorderPart]::FooterBottomLeft), $this.GetPart([TableBorderPart]::FooterBottom), $this.GetPart([TableBorderPart]::FooterBottomSeparator), $this.GetPart([TableBorderPart]::FooterBottomRight)) }
        }
        return @("", "", "", "")
    }

    [TableBorder] GetSafeBorder([bool]$safe) {
        if ($safe) { return [AsciiTableBorder]::new() }
        return $this
    }

    static [TableBorder] GetSafeBorder([RenderOptions]$options, [object]$borderable) {
        if ($null -eq $borderable -or -not ('Border' -in $borderable.PSObject.Properties.Name)) { return [NoTableBorder]::new() }
        $border = $borderable.Border
        if ($null -eq $border) { return [NoTableBorder]::new() }
        if ($borderable.PSObject.Properties.Name -contains 'UseSafeBorder' -and !$borderable.UseSafeBorder) { return $border }
        if (!$options.Unicode) { return $border.GetSafeBorder($true) }
        return $border
    }
}

class NoTableBorder : TableBorder {
    [bool] get_Visible() { return $false }
    [bool] get_UsePadding() { return $true }
    [string] GetPart([TableBorderPart]$part) { return "" }
}

class AsciiTableBorder : TableBorder {
    [bool] get_SupportsRowSeparator() { return $true }
    [string] GetPart([TableBorderPart]$part) {
        switch ($part) {
            ([TableBorderPart]::HeaderTopLeft) { return "+" }
            ([TableBorderPart]::HeaderTop) { return "-" }
            ([TableBorderPart]::HeaderTopSeparator) { return "+" }
            ([TableBorderPart]::HeaderTopRight) { return "+" }
            ([TableBorderPart]::HeaderLeft) { return "|" }
            ([TableBorderPart]::HeaderSeparator) { return "|" }
            ([TableBorderPart]::HeaderRight) { return "|" }
            ([TableBorderPart]::HeaderBottomLeft) { return "+" }
            ([TableBorderPart]::HeaderBottom) { return "-" }
            ([TableBorderPart]::HeaderBottomSeparator) { return "+" }
            ([TableBorderPart]::HeaderBottomRight) { return "+" }
            ([TableBorderPart]::CellLeft) { return "|" }
            ([TableBorderPart]::CellSeparator) { return "|" }
            ([TableBorderPart]::CellRight) { return "|" }
            ([TableBorderPart]::FooterTopLeft) { return "+" }
            ([TableBorderPart]::FooterTop) { return "-" }
            ([TableBorderPart]::FooterTopSeparator) { return "+" }
            ([TableBorderPart]::FooterTopRight) { return "+" }
            ([TableBorderPart]::FooterBottomLeft) { return "+" }
            ([TableBorderPart]::FooterBottom) { return "-" }
            ([TableBorderPart]::FooterBottomSeparator) { return "+" }
            ([TableBorderPart]::FooterBottomRight) { return "+" }
            ([TableBorderPart]::RowLeft) { return "+" }
            ([TableBorderPart]::RowCenter) { return "-" }
            ([TableBorderPart]::RowSeparator) { return "+" }
            ([TableBorderPart]::RowRight) { return "+" }
        }
        return ""
    }
}

class SquareTableBorder : TableBorder {
    [bool] get_SupportsRowSeparator() { return $true }
    [string] GetPart([TableBorderPart]$part) {
        switch ($part) {
            ([TableBorderPart]::HeaderTopLeft) { return "┌" }
            ([TableBorderPart]::HeaderTop) { return "─" }
            ([TableBorderPart]::HeaderTopSeparator) { return "┬" }
            ([TableBorderPart]::HeaderTopRight) { return "┐" }
            ([TableBorderPart]::HeaderLeft) { return "│" }
            ([TableBorderPart]::HeaderSeparator) { return "│" }
            ([TableBorderPart]::HeaderRight) { return "│" }
            ([TableBorderPart]::HeaderBottomLeft) { return "├" }
            ([TableBorderPart]::HeaderBottom) { return "─" }
            ([TableBorderPart]::HeaderBottomSeparator) { return "┼" }
            ([TableBorderPart]::HeaderBottomRight) { return "┤" }
            ([TableBorderPart]::CellLeft) { return "│" }
            ([TableBorderPart]::CellSeparator) { return "│" }
            ([TableBorderPart]::CellRight) { return "│" }
            ([TableBorderPart]::FooterTopLeft) { return "├" }
            ([TableBorderPart]::FooterTop) { return "─" }
            ([TableBorderPart]::FooterTopSeparator) { return "┼" }
            ([TableBorderPart]::FooterTopRight) { return "┤" }
            ([TableBorderPart]::FooterBottomLeft) { return "└" }
            ([TableBorderPart]::FooterBottom) { return "─" }
            ([TableBorderPart]::FooterBottomSeparator) { return "┴" }
            ([TableBorderPart]::FooterBottomRight) { return "┘" }
            ([TableBorderPart]::RowLeft) { return "├" }
            ([TableBorderPart]::RowCenter) { return "─" }
            ([TableBorderPart]::RowSeparator) { return "┼" }
            ([TableBorderPart]::RowRight) { return "┤" }
        }
        return ""
    }
}

class RoundedTableBorder : TableBorder {
    [bool] get_SupportsRowSeparator() { return $true }
    [string] GetPart([TableBorderPart]$part) {
        switch ($part) {
            ([TableBorderPart]::HeaderTopLeft) { return "╭" }
            ([TableBorderPart]::HeaderTop) { return "─" }
            ([TableBorderPart]::HeaderTopSeparator) { return "┬" }
            ([TableBorderPart]::HeaderTopRight) { return "╮" }
            ([TableBorderPart]::HeaderLeft) { return "│" }
            ([TableBorderPart]::HeaderSeparator) { return "│" }
            ([TableBorderPart]::HeaderRight) { return "│" }
            ([TableBorderPart]::HeaderBottomLeft) { return "├" }
            ([TableBorderPart]::HeaderBottom) { return "─" }
            ([TableBorderPart]::HeaderBottomSeparator) { return "┼" }
            ([TableBorderPart]::HeaderBottomRight) { return "┤" }
            ([TableBorderPart]::CellLeft) { return "│" }
            ([TableBorderPart]::CellSeparator) { return "│" }
            ([TableBorderPart]::CellRight) { return "│" }
            ([TableBorderPart]::FooterTopLeft) { return "├" }
            ([TableBorderPart]::FooterTop) { return "─" }
            ([TableBorderPart]::FooterTopSeparator) { return "┼" }
            ([TableBorderPart]::FooterTopRight) { return "┤" }
            ([TableBorderPart]::FooterBottomLeft) { return "╰" }
            ([TableBorderPart]::FooterBottom) { return "─" }
            ([TableBorderPart]::FooterBottomSeparator) { return "┴" }
            ([TableBorderPart]::FooterBottomRight) { return "╯" }
            ([TableBorderPart]::RowLeft) { return "├" }
            ([TableBorderPart]::RowCenter) { return "─" }
            ([TableBorderPart]::RowSeparator) { return "┼" }
            ([TableBorderPart]::RowRight) { return "┤" }
        }
        return ""
    }
}

class HeavyTableBorder : TableBorder {
    [bool] get_SupportsRowSeparator() { return $true }
    [string] GetPart([TableBorderPart]$part) {
        switch ($part) {
            ([TableBorderPart]::HeaderTopLeft) { return "┏" }
            ([TableBorderPart]::HeaderTop) { return "━" }
            ([TableBorderPart]::HeaderTopSeparator) { return "┳" }
            ([TableBorderPart]::HeaderTopRight) { return "┓" }
            ([TableBorderPart]::HeaderLeft) { return "┃" }
            ([TableBorderPart]::HeaderSeparator) { return "┃" }
            ([TableBorderPart]::HeaderRight) { return "┃" }
            ([TableBorderPart]::HeaderBottomLeft) { return "┣" }
            ([TableBorderPart]::HeaderBottom) { return "━" }
            ([TableBorderPart]::HeaderBottomSeparator) { return "╋" }
            ([TableBorderPart]::HeaderBottomRight) { return "┫" }
            ([TableBorderPart]::CellLeft) { return "┃" }
            ([TableBorderPart]::CellSeparator) { return "┃" }
            ([TableBorderPart]::CellRight) { return "┃" }
            ([TableBorderPart]::FooterTopLeft) { return "┣" }
            ([TableBorderPart]::FooterTop) { return "━" }
            ([TableBorderPart]::FooterTopSeparator) { return "╋" }
            ([TableBorderPart]::FooterTopRight) { return "┫" }
            ([TableBorderPart]::FooterBottomLeft) { return "┗" }
            ([TableBorderPart]::FooterBottom) { return "━" }
            ([TableBorderPart]::FooterBottomSeparator) { return "┻" }
            ([TableBorderPart]::FooterBottomRight) { return "┛" }
            ([TableBorderPart]::RowLeft) { return "┣" }
            ([TableBorderPart]::RowCenter) { return "━" }
            ([TableBorderPart]::RowSeparator) { return "╋" }
            ([TableBorderPart]::RowRight) { return "┫" }
        }
        return ""
    }
}

class DoubleTableBorder : TableBorder {
    [bool] get_SupportsRowSeparator() { return $true }
    [string] GetPart([TableBorderPart]$part) {
        switch ($part) {
            ([TableBorderPart]::HeaderTopLeft) { return "╔" }
            ([TableBorderPart]::HeaderTop) { return "═" }
            ([TableBorderPart]::HeaderTopSeparator) { return "╦" }
            ([TableBorderPart]::HeaderTopRight) { return "╗" }
            ([TableBorderPart]::HeaderLeft) { return "║" }
            ([TableBorderPart]::HeaderSeparator) { return "║" }
            ([TableBorderPart]::HeaderRight) { return "║" }
            ([TableBorderPart]::HeaderBottomLeft) { return "╠" }
            ([TableBorderPart]::HeaderBottom) { return "═" }
            ([TableBorderPart]::HeaderBottomSeparator) { return "╬" }
            ([TableBorderPart]::HeaderBottomRight) { return "╣" }
            ([TableBorderPart]::CellLeft) { return "║" }
            ([TableBorderPart]::CellSeparator) { return "║" }
            ([TableBorderPart]::CellRight) { return "║" }
            ([TableBorderPart]::FooterTopLeft) { return "╠" }
            ([TableBorderPart]::FooterTop) { return "═" }
            ([TableBorderPart]::FooterTopSeparator) { return "╬" }
            ([TableBorderPart]::FooterTopRight) { return "╣" }
            ([TableBorderPart]::FooterBottomLeft) { return "╚" }
            ([TableBorderPart]::FooterBottom) { return "═" }
            ([TableBorderPart]::FooterBottomSeparator) { return "╩" }
            ([TableBorderPart]::FooterBottomRight) { return "╝" }
            ([TableBorderPart]::RowLeft) { return "╠" }
            ([TableBorderPart]::RowCenter) { return "═" }
            ([TableBorderPart]::RowSeparator) { return "╬" }
            ([TableBorderPart]::RowRight) { return "╣" }
        }
        return ""
    }
}

class MarkdownTableBorder : TableBorder {
    [bool] get_SupportsRowSeparator() { return $false }
    [string] GetPart([TableBorderPart]$part) {
        switch ($part) {
            ([TableBorderPart]::HeaderTopLeft) { return " " }
            ([TableBorderPart]::HeaderTop) { return " " }
            ([TableBorderPart]::HeaderTopSeparator) { return " " }
            ([TableBorderPart]::HeaderTopRight) { return " " }
            ([TableBorderPart]::HeaderLeft) { return "|" }
            ([TableBorderPart]::HeaderSeparator) { return "|" }
            ([TableBorderPart]::HeaderRight) { return "|" }
            ([TableBorderPart]::HeaderBottomLeft) { return "|" }
            ([TableBorderPart]::HeaderBottom) { return "-" }
            ([TableBorderPart]::HeaderBottomSeparator) { return "|" }
            ([TableBorderPart]::HeaderBottomRight) { return "|" }
            ([TableBorderPart]::CellLeft) { return "|" }
            ([TableBorderPart]::CellSeparator) { return "|" }
            ([TableBorderPart]::CellRight) { return "|" }
            ([TableBorderPart]::FooterTopLeft) { return " " }
            ([TableBorderPart]::FooterTop) { return " " }
            ([TableBorderPart]::FooterTopSeparator) { return " " }
            ([TableBorderPart]::FooterTopRight) { return " " }
            ([TableBorderPart]::FooterBottomLeft) { return " " }
            ([TableBorderPart]::FooterBottom) { return " " }
            ([TableBorderPart]::FooterBottomSeparator) { return " " }
            ([TableBorderPart]::FooterBottomRight) { return " " }
            ([TableBorderPart]::RowLeft) { return " " }
            ([TableBorderPart]::RowCenter) { return " " }
            ([TableBorderPart]::RowSeparator) { return " " }
            ([TableBorderPart]::RowRight) { return " " }
        }
        return ""
    }
}
class TableMeasurer {
    hidden [object]$_table
    hidden [RenderOptions]$_options
    hidden [int]$_explicitWidth
    hidden [TableBorder]$_border
    hidden [bool]$_padRightCell

    TableMeasurer([object]$table, [RenderOptions]$options) {
        $this._table = $table
        $this._options = $options
        $this._explicitWidth = if ($null -ne $table.Width) { $table.Width.Value } else { -1 }
        $this._border = $table.Border
        $this._padRightCell = $table.PadRightCell
    }

    [int] CalculateTotalCellWidth([int]$maxWidth) {
        $totalCellWidth = $maxWidth
        if ($this._explicitWidth -ne -1) {
            $totalCellWidth = [Math]::Min($this._explicitWidth, $maxWidth)
        }
        return $totalCellWidth - $this.GetNonColumnWidth()
    }

    [int] GetNonColumnWidth() {
        $hideBorder = !$this._border.get_Visible()
        $usePadding = $this._border.get_UsePadding()
        $separators = if ($hideBorder) { 0 } else { $this._table.Columns.Count - 1 }
        $edges = if ($hideBorder -or !$usePadding) { 0 } else { 2 }
        $padding = 0
        if ($usePadding) {
            foreach ($c in $this._table.Columns) {
                if ($null -ne $c.Padding) { $padding += $c.Padding.GetWidth() }
            }
            if (!$this._padRightCell) {
                $lastCol = $this._table.Columns[$this._table.Columns.Count - 1]
                if ($null -ne $lastCol.Padding) { $padding -= $lastCol.Padding.GetRightSafe() }
            }
        }
        return $separators + $edges + $padding
    }

    [List[int]] CalculateColumnWidths([int]$maxWidth) {
        $widths = [List[int]]::new()
        foreach ($c in $this._table.Columns) {
            $widths.Add($this.MeasureColumn($c, $maxWidth).Max)
        }

        $tableWidth = 0
        foreach ($w in $widths) { $tableWidth += $w }

        if ($tableWidth -gt $maxWidth) {
            $wrappable = [List[bool]]::new()
            foreach ($c in $this._table.Columns) { $wrappable.Add(!$c.NoWrap) }

            $widths = [TableMeasurer]::CollapseWidths($widths, $wrappable, $maxWidth)

            $tableWidth = 0
            foreach ($w in $widths) { $tableWidth += $w }

            if ($tableWidth -gt $maxWidth) {
                $excessWidth = $tableWidth - $maxWidth
                # Very simple reduce: subtract 1 from largest until we meet maxWidth
                while ($excessWidth -gt 0) {
                    $maxW = -1; $maxIdx = -1
                    for ($i=0; $i -lt $widths.Count; $i++) {
                        if ($widths[$i] -gt $maxW) { $maxW = $widths[$i]; $maxIdx = $i }
                    }
                    if ($maxW -le 1) { break }
                    $widths[$maxIdx] -= 1
                    $excessWidth -= 1
                }
            }
        }

        $tableWidth = 0
        foreach ($w in $widths) { $tableWidth += $w }

        if ($tableWidth -lt $maxWidth -and $this._table.Expand) {
            $flexible = [List[bool]]::new()
            $hasFlex = $false
            foreach ($c in $this._table.Columns) {
                $flex = ($null -eq $c.Width)
                $flexible.Add($flex)
                if ($flex) { $hasFlex = $true }
            }

            if ($hasFlex) {
                $excess = $maxWidth - $tableWidth
                while ($excess -gt 0) {
                    # Add to smallest flexible column
                    $minW = 999999; $minIdx = -1
                    for ($i=0; $i -lt $widths.Count; $i++) {
                        if ($flexible[$i] -and $widths[$i] -lt $minW) {
                            $minW = $widths[$i]; $minIdx = $i
                        }
                    }
                    if ($minIdx -eq -1) { break }
                    $widths[$minIdx] += 1
                    $excess -= 1
                }
            }
        }

        return $widths
    }

    [Measurement] MeasureColumn([TableColumn]$column, [int]$maxWidth) {
        if ($null -ne $column.Width) {
            return [Measurement]::new($column.Width.Value, $column.Width.Value)
        }
        $colIdx = $this._table.Columns.IndexOf($column)
        $minWidths = [List[int]]::new()
        $maxWidths = [List[int]]::new()

        $headM = $column.Header.Measure($this._options, $maxWidth)
        $footM = if ($null -ne $column.Footer) { $column.Footer.Measure($this._options, $maxWidth) } else { $headM }

        $minWidths.Add([Math]::Min($headM.Min, $footM.Min))
        $maxWidths.Add([Math]::Max($headM.Max, $footM.Max))

        foreach ($row in $this._table.Rows) {
            $currCol = 0
            foreach ($item in $row.Items) {
                if ($currCol -eq $colIdx) {
                    if ($item -is [TableCell]) {
                        $cSpan = $item.ColumnSpan
                        $cellM = $item.Content.Measure($this._options, $maxWidth)
                        if ($cSpan -gt 1) {
                            $minWidths.Add([Math]::Floor($cellM.Min / $cSpan))
                            $maxWidths.Add([Math]::Floor($cellM.Max / $cSpan))
                        } else {
                            $minWidths.Add($cellM.Min)
                            $maxWidths.Add($cellM.Max)
                        }
                    } else {
                        $rM = $item.Measure($this._options, $maxWidth)
                        $minWidths.Add($rM.Min)
                        $maxWidths.Add($rM.Max)
                    }
                    break
                } elseif ($item -is [TableCell] -and ($currCol + $item.ColumnSpan) -gt $colIdx) {
                    $cSpan = $item.ColumnSpan
                    $cellM = $item.Content.Measure($this._options, $maxWidth)
                    $minWidths.Add([Math]::Floor($cellM.Min / $cSpan))
                    $maxWidths.Add([Math]::Floor($cellM.Max / $cSpan))
                    break
                }
                $currCol += if ($item -is [TableCell]) { $item.ColumnSpan } else { 1 }
            }
        }

        $pad = if ($null -ne $column.Padding) { $column.Padding.GetWidth() } else { 0 }

        $cMin = if ($minWidths.Count -gt 0) { [Linq.Enumerable]::Max([int[]]$minWidths) } else { $pad }
        $cMax = if ($maxWidths.Count -gt 0) { [Linq.Enumerable]::Max([int[]]$maxWidths) } else { $maxWidth }

        return [Measurement]::new($cMin, $cMax)
    }

    static hidden [List[int]] CollapseWidths([List[int]]$widths, [List[bool]]$wrappable, [int]$maxWidth) {
        $totalWidth = 0
        foreach ($w in $widths) { $totalWidth += $w }
        $excessWidth = $totalWidth - $maxWidth

        $hasWrap = $false
        foreach ($w in $wrappable) { if ($w) { $hasWrap = $true; break } }

        if ($hasWrap) {
            while ($totalWidth -ne 0 -and $excessWidth -gt 0) {
                $maxCol = -1
                for ($i=0; $i -lt $widths.Count; $i++) {
                    if ($wrappable[$i] -and $widths[$i] -gt $maxCol) { $maxCol = $widths[$i] }
                }

                $secondMax = -1
                for ($i=0; $i -lt $widths.Count; $i++) {
                    if ($wrappable[$i] -and $widths[$i] -ne $maxCol -and $widths[$i] -gt $secondMax) { $secondMax = $widths[$i] }
                }
                if ($secondMax -eq -1) { $secondMax = 1 }

                $diff = $maxCol - $secondMax

                $ratios = [List[int]]::new()
                $anyRatio = $false
                for ($i=0; $i -lt $widths.Count; $i++) {
                    if ($widths[$i] -eq $maxCol -and $wrappable[$i]) { $ratios.Add(1); $anyRatio = $true } else { $ratios.Add(0) }
                }

                if (!$anyRatio -or $diff -eq 0) { break }

                $toReduce = [Math]::Min($excessWidth, $diff)
                # Apply reduction to max cols
                for ($i=0; $i -lt $widths.Count; $i++) {
                    if ($ratios[$i] -gt 0) { $widths[$i] -= $toReduce }
                }

                $totalWidth = 0
                foreach ($w in $widths) { $totalWidth += $w }
                $excessWidth = $totalWidth - $maxWidth
            }
        }
        return $widths
    }
}


