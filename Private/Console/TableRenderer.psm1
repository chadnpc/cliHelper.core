using namespace System
using namespace System.Collections.Generic

using module .\Enums.psm1
using module .\Colors.psm1
using module .\Rendering.psm1
using module .\Widgets.psm1
using module .\Tables.psm1

class TableRendererContext {
  [object]$Table
  [RenderOptions]$Options
  [List[TableRow]]$Rows
  [int]$TableWidth
  [int]$MaxWidth

  [TableBorder]$Border
  [Style]$BorderStyle
  [bool]$ShowHeaders
  [bool]$ShowRowSeparators
  [bool]$ShowFooters
  [bool]$Expand
  [bool]$PadRightCell
  [bool]$IsGrid
  [bool]$ShowBorder
  [bool]$HideBorder
  [bool]$HasRows
  [bool]$HasFooters
  [List[TableColumn]]$Columns
  [TableTitle]$Title
  [TableTitle]$Caption

  TableRendererContext([object]$table, [RenderOptions]$options, [List[TableRow]]$rows, [int]$tableWidth, [int]$maxWidth) {
    $this.Table = $table
    $this.Options = $options
    $this.Rows = $rows
    $this.TableWidth = $tableWidth
    $this.MaxWidth = $maxWidth

    $this.Border = $table.Border
    $this.BorderStyle = if ($null -ne $table.BorderStyle) { $table.BorderStyle } else { [Style]::Plain }
    $this.ShowHeaders = $table.ShowHeaders
    $this.ShowRowSeparators = $table.ShowRowSeparators
    $this.ShowFooters = $table.ShowFooters
    $this.Expand = $table.Expand
    $this.PadRightCell = $table.PadRightCell
    $this.IsGrid = $table.IsGrid
    $this.ShowBorder = $table.Border.get_Visible()
    $this.HideBorder = !$this.ShowBorder
    $this.HasRows = $rows.Count -gt 0
    $this.HasFooters = $false
    foreach ($c in $table.Columns) { if ($null -ne $c.Footer) { $this.HasFooters = $true; break } }
    $this.Columns = $table.Columns
    $this.Title = $table.Title
    $this.Caption = $table.Caption
  }
}

class TableRenderer {
  static hidden [Style]$_defaultHeadingStyle = [Color]::Silver
  static hidden [Style]$_defaultCaptionStyle = [Color]::Grey

  static [List[Segment]] Render([TableRendererContext]$context, [List[int]]$columnWidths) {
    $badWidth = $false
    foreach ($w in $columnWidths) { if ($w -lt 0) { $badWidth = $true; break } }
    if ($context.TableWidth -le 0 -or $context.TableWidth -gt $context.MaxWidth -or $badWidth) {
      $ret = [List[Segment]]::new()
      $ret.Add([Segment]::new("…", $context.BorderStyle))
      return $ret
    }

    $result = [List[Segment]]::new()
    $result.AddRange([TableRenderer]::RenderAnnotation($context, $context.Title, [TableRenderer]::_defaultHeadingStyle))

    for ($index = 0; $index -lt $context.Rows.Count; $index++) {
      $row = $context.Rows[$index]
      $isFirstRow = ($index -eq 0)
      $isLastRow = ($index -eq $context.Rows.Count - 1)

      $cellHeight = 1
      # Array of custom objects holding state
      $cells = [List[object]]::new()
      $columnIndex = 0

      foreach ($item in $row.Items) {
        $cellRenderable = $item
        $span = 1
        if ($item -is [TableCell]) {
          $cellRenderable = $item.Content
          $span = $item.ColumnSpan
        }

        $cellWidth = $columnWidths[$columnIndex]
        if ($span -gt 1) {
          for ($i = 1; $i -lt $span; $i++) {
            if (($columnIndex + $i) -lt $columnWidths.Count) {
              if ($context.ShowBorder) { $cellWidth += 1 }
              $cellWidth += $columnWidths[$columnIndex + $i]
              if (($context.ShowBorder -and $context.Border.get_UsePadding()) -or $context.IsGrid) {
                $cellWidth += $context.Columns[$columnIndex + $i].Padding.GetLeftSafe()
                $cellWidth += $context.Columns[$columnIndex + $i].Padding.GetRightSafe()
              }
            }
          }
        }

        $align = $context.Columns[$columnIndex].Alignment
        $childContext = [RenderOptions]::new()
        $childContext.Ansi = $context.Options.Ansi
        $childContext.ColorSystem = $context.Options.ColorSystem
        $childContext.Justification = $align
        $childContext.Unicode = $context.Options.Unicode

        $segs = $cellRenderable.Render($childContext, $cellWidth)
        $lines = [Segment]::SplitLines($segs, $cellWidth)
        $cellHeight = [Math]::Max($cellHeight, $lines.Count)

        $cells.Add(@{ Lines = $lines; Width = $cellWidth; ColumnIndex = $columnIndex; Span = $span; IsNull = $false })

        for ($i = 1; $i -lt $span; $i++) {
          $cells.Add(@{ Lines = $null; Width = 0; ColumnIndex = $columnIndex + $i; Span = 0; IsNull = $true })
        }
        $columnIndex += $span
      }

      if ($isFirstRow -and $context.ShowBorder) {
        $sep = $context.Border.GetColumnRow([TablePart]::Top, $columnWidths, $context.Columns)
        if (-not [string]::IsNullOrEmpty($sep)) {
          $result.Add([Segment]::new($sep, $context.BorderStyle))
          $result.Add([Segment]::LineBreak)
        }
      }

      if ($context.ShowFooters -and $isLastRow -and $context.ShowBorder -and $context.HasFooters) {
        $tb = $context.Border.GetColumnRow([TablePart]::FooterSeparator, $columnWidths, $context.Columns)
        if (-not [string]::IsNullOrEmpty($tb)) {
          $result.Add([Segment]::new($tb, $context.BorderStyle))
          $result.Add([Segment]::LineBreak)
        }
      }

      foreach ($c in $cells) {
        if (!$c.IsNull -and $c.Lines.Count -lt $cellHeight) {
          while ($c.Lines.Count -lt $cellHeight) {
            $c.Lines.Add([SegmentLine]::new())
          }
        }
      }

      $firstNonNull = -1; $lastNonNull = -1
      for ($i = 0; $i -lt $cells.Count; $i++) {
        if (!$cells[$i].IsNull) {
          if ($firstNonNull -eq -1) { $firstNonNull = $i }
          $lastNonNull = $i
        }
      }

      for ($cellRowIndex = 0; $cellRowIndex -lt $cellHeight; $cellRowIndex++) {
        $rowResult = [List[Segment]]::new()

        for ($cellIndex = 0; $cellIndex -lt $cells.Count; $cellIndex++) {
          $cData = $cells[$cellIndex]
          if ($cData.IsNull) { continue }

          $isFirstCell = ($cellIndex -eq $firstNonNull)
          $isLastCell = ($cellIndex -eq $lastNonNull)
          $actualCol = $cData.ColumnIndex
          $cellLines = $cData.Lines
          $cellW = $cData.Width
          $cellSpan = $cData.Span

          if ($isFirstCell -and $context.ShowBorder) {
            $part = if ($isFirstRow -and $context.ShowHeaders) { [TableBorderPart]::HeaderLeft } else { [TableBorderPart]::CellLeft }
            $rowResult.Add([Segment]::new($context.Border.GetPart($part), $context.BorderStyle))
          }

          if (($context.ShowBorder -and $context.Border.get_UsePadding()) -or $context.IsGrid) {
            $lPad = $context.Columns[$actualCol].Padding.GetLeftSafe()
            if ($lPad -gt 0) { $rowResult.Add([Segment]::Padding($lPad)) }
          }

          $rowResult.AddRange($cellLines[$cellRowIndex].Segments)

          $len = $cellLines[$cellRowIndex].CellCount()
          if ($len -lt $cellW) {
            $rowResult.Add([Segment]::Padding($cellW - $len))
          }

          $rightCol = $actualCol + $cellSpan - 1
          if (($context.ShowBorder -and $context.Border.get_UsePadding()) -or ($context.HideBorder -and !$isLastCell) -or ($context.HideBorder -and $isLastCell -and $context.IsGrid -and $context.PadRightCell)) {
            $rPad = $context.Columns[$rightCol].Padding.GetRightSafe()
            if ($rPad -gt 0) { $rowResult.Add([Segment]::Padding($rPad)) }
          }

          if ($isLastCell -and $context.ShowBorder) {
            $part = if ($isFirstRow -and $context.ShowHeaders) { [TableBorderPart]::HeaderRight } else { [TableBorderPart]::CellRight }
            $rowResult.Add([Segment]::new($context.Border.GetPart($part), $context.BorderStyle))
          } elseif ($context.ShowBorder) {
            $part = if ($isFirstRow -and $context.ShowHeaders) { [TableBorderPart]::HeaderSeparator } else { [TableBorderPart]::CellSeparator }
            $rowResult.Add([Segment]::new($context.Border.GetPart($part), $context.BorderStyle))
          }
        }

        if ([Segment]::CellCount($rowResult) -gt $context.MaxWidth) {
          $result.AddRange([Segment]::Truncate($rowResult, $context.MaxWidth))
        } else {
          $result.AddRange($rowResult)
        }
        $result.Add([Segment]::LineBreak)
      }

      if ($isFirstRow -and $context.ShowBorder -and $context.ShowHeaders -and $context.HasRows) {
        $sep = $context.Border.GetColumnRow([TablePart]::HeaderSeparator, $columnWidths, $context.Columns)
        $result.Add([Segment]::new($sep, $context.BorderStyle))
        $result.Add([Segment]::LineBreak)
      }

      if ($context.Border.get_SupportsRowSeparator() -and $context.ShowRowSeparators -and (!$isFirstRow -or ($isFirstRow -and !$context.ShowHeaders)) -and !$isLastRow) {
        $hasVisFooter = ($context.ShowFooters -and $context.HasFooters)
        $isNextLastLine = ($index -eq $context.Rows.Count - 2)
        if (-not ($hasVisFooter -and $isNextLastLine)) {
          $sep = $context.Border.GetColumnRow([TablePart]::RowSeparator, $columnWidths, $context.Columns)
          $result.Add([Segment]::new($sep, $context.BorderStyle))
          $result.Add([Segment]::LineBreak)
        }
      }

      if ($isLastRow -and $context.ShowBorder) {
        $sep = $context.Border.GetColumnRow([TablePart]::Bottom, $columnWidths, $context.Columns)
        if (-not [string]::IsNullOrEmpty($sep)) {
          $result.Add([Segment]::new($sep, $context.BorderStyle))
          $result.Add([Segment]::LineBreak)
        }
      }
    }

    $result.AddRange([TableRenderer]::RenderAnnotation($context, $context.Caption, [TableRenderer]::_defaultCaptionStyle))
    return $result
  }

  static hidden [IEnumerable[Segment]] RenderAnnotation([TableRendererContext]$context, [TableTitle]$header, [Style]$defaultStyle) {
    if ($null -eq $header) { return [Segment[]]@() }

    $styleToUse = if ($null -ne $header.Style) { $header.Style } else { $defaultStyle }
    $p = [Markup]::new($header.Text, $styleToUse)
    $p.Justify = [Justify]::Center
    $p.Overflow = [Overflow]::Ellipsis

    $segs = [List[Segment]]::new()
    $segs.AddRange($p.Render($context.Options, $context.TableWidth))
    $segs.Add([Segment]::LineBreak)
    return $segs
  }
}

