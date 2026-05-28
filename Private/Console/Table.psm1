using namespace System
using namespace System.Collections.Generic
using namespace System.Linq

using module ..\Enums.psm1
using module ..\Abstracts.psm1
using module .\Rendering.psm1
using module .\Widgets.psm1
using module .\Tables.psm1
using module .\TableRenderer.psm1

class Table : IRenderable {
  hidden [List[TableColumn]]$_columns
  [List[TableColumn]]$Columns
  [TableRowCollection]$Rows

  [TableBorder]$Border
  [Style]$BorderStyle
  [bool]$UseSafeBorder
  [bool]$ShowHeaders
  [bool]$ShowRowSeparators
  [bool]$ShowFooters
  [bool]$Expand
  [Nullable[int]]$Width
  [TableTitle]$Title
  [TableTitle]$Caption
  [bool]$IsGrid
  [bool]$PadRightCell

  Table() {
    $this._columns = [List[TableColumn]]::new()
    $this.Columns = $this._columns
    $this.Rows = [TableRowCollection]::new($this)
    $this.Border = [SquareTableBorder]::new()
    $this.UseSafeBorder = $true
    $this.ShowHeaders = $true
    $this.ShowFooters = $true
    $this.PadRightCell = $true
  }

  [Table] AddColumn([TableColumn]$column) {
    if ($this.Rows.Count -gt 0) {
      throw [InvalidOperationException]::new("Cannot add new columns to table with existing rows.")
    }
    $this._columns.Add($column)
    return $this
  }

  [Table] AddColumn([string]$header) {
    return $this.AddColumn([TableColumn]::new($header))
  }

  [Table] AddRow([IEnumerable[IRenderable]]$columns) {
    $this.Rows.Add([TableRow]::new($columns))
    return $this
  }

  [Table] AddRow([IRenderable[]]$columns) {
    return $this.AddRow([IEnumerable[IRenderable]]$columns)
  }

  [Table] AddRow([string[]]$columns) {
    $list = [List[IRenderable]]::new()
    foreach ($c in $columns) { $list.Add([Markup]::new($c)) }
    return $this.AddRow($list)
  }

  [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
    $measurer = [TableMeasurer]::new($this, $options)
    $totalCellWidth = $measurer.CalculateTotalCellWidth($maxWidth)

    $min = 0; $max = 0
    foreach ($c in $this._columns) {
      $m = $measurer.MeasureColumn($c, $totalCellWidth)
      $min += $m.Min
      $max += $m.Max
    }

    $nonCol = $measurer.GetNonColumnWidth()
    $minTableWidth = $min + $nonCol
    $maxTableWidth = if ($null -ne $this.Width) { $this.Width } else { $max + $nonCol }

    return [Measurement]::new($minTableWidth, $maxTableWidth)
  }

  [Segment[]] Render([RenderOptions]$options, [int]$maxWidth) {
    $measurer = [TableMeasurer]::new($this, $options)
    $totalCellWidth = $measurer.CalculateTotalCellWidth($maxWidth)
    $columnWidths = $measurer.CalculateColumnWidths($totalCellWidth)

    $tableWidth = 0
    foreach ($w in $columnWidths) { $tableWidth += $w }
    $tableWidth += $measurer.GetNonColumnWidth()

    $renderedRows = $this.GetRenderableRows()
    $ctx = [TableRendererContext]::new($this, $options, $renderedRows, $tableWidth, $maxWidth)

    return [TableRenderer]::Render($ctx, $columnWidths).ToArray()
  }

  hidden [List[TableRow]] GetRenderableRows() {
    $renderedRows = [List[TableRow]]::new()

    if ($this.ShowHeaders) {
      $heads = [List[IRenderable]]::new()
      foreach ($c in $this._columns) { $heads.Add($c.Header) }
      $renderedRows.Add([TableRow]::Header($heads))
    }

    foreach ($r in $this.Rows) {
      $renderedRows.Add($r)
    }

    $anyFooter = $false
    foreach ($c in $this._columns) { if ($null -ne $c.Footer) { $anyFooter = $true; break } }

    if ($this.ShowFooters -and $anyFooter) {
      $foots = [List[IRenderable]]::new()
      foreach ($c in $this._columns) {
        if ($null -ne $c.Footer) { $foots.Add($c.Footer) } else { $foots.Add([Text]::Empty) }
      }
      $renderedRows.Add([TableRow]::Footer($foots))
    }

    return $renderedRows
  }
}

