using namespace System
using namespace System.Collections.Generic
using namespace System.Linq

using module ..\Enums.psm1
using module ..\Abstracts.psm1
using module .\Rendering.psm1
using module .\Internal.psm1
using module .\Widgets.psm1

class TreeGuide {
    [TreeGuide] get_SafeTreeGuide() { return $this }
    [string] GetPart([TreeGuidePart]$part) { return '' }

    static [TreeGuide] get_Line() { return [LineTreeGuide]::new() }
    static [TreeGuide] get_BoldLine() { return [BoldLineTreeGuide]::new() }
    static [TreeGuide] get_DoubleLine() { return [DoubleLineTreeGuide]::new() }
    static [TreeGuide] get_Ascii() { return [AsciiTreeGuide]::new() }

    static [TreeGuide] GetSafeTreeGuide([RenderOptions]$options, [TreeGuide]$guide) {
        if ($null -eq $guide) { return [TreeGuide]::get_Line() }
        if (!$options.Unicode) { return $guide.get_SafeTreeGuide() }
        return $guide
    }
}

class LineTreeGuide : TreeGuide {
    [TreeGuide] get_SafeTreeGuide() { return [AsciiTreeGuide]::new() }
    [string] GetPart([TreeGuidePart]$part) {
        switch ($part) {
            ([TreeGuidePart]::Space) { return '    ' }
            ([TreeGuidePart]::Continue) { return '│   ' }
            ([TreeGuidePart]::Fork) { return '├── ' }
            ([TreeGuidePart]::End) { return '└── ' }
        }
        return ''
    }
}

class BoldLineTreeGuide : TreeGuide {
    [TreeGuide] get_SafeTreeGuide() { return [AsciiTreeGuide]::new() }
    [string] GetPart([TreeGuidePart]$part) {
        switch ($part) {
            ([TreeGuidePart]::Space) { return '    ' }
            ([TreeGuidePart]::Continue) { return '┃   ' }
            ([TreeGuidePart]::Fork) { return '┣━━ ' }
            ([TreeGuidePart]::End) { return '┗━━ ' }
        }
        return ''
    }
}

class DoubleLineTreeGuide : TreeGuide {
    [TreeGuide] get_SafeTreeGuide() { return [AsciiTreeGuide]::new() }
    [string] GetPart([TreeGuidePart]$part) {
        switch ($part) {
            ([TreeGuidePart]::Space) { return '    ' }
            ([TreeGuidePart]::Continue) { return '║   ' }
            ([TreeGuidePart]::Fork) { return '╠══ ' }
            ([TreeGuidePart]::End) { return '╚══ ' }
        }
        return ''
    }
}

class AsciiTreeGuide : TreeGuide {
    [string] GetPart([TreeGuidePart]$part) {
        switch ($part) {
            ([TreeGuidePart]::Space) { return '    ' }
            ([TreeGuidePart]::Continue) { return '|   ' }
            ([TreeGuidePart]::Fork) { return '|-- ' }
            ([TreeGuidePart]::End) { return '`-- ' }
        }
        return ''
    }
}

class TreeNode {
    [IRenderable]$Renderable
    [List[TreeNode]]$Nodes
    [bool]$Expanded

    TreeNode([IRenderable]$renderable) {
        $this.Renderable = $renderable
        $this.Nodes = [List[TreeNode]]::new()
        $this.Expanded = $true
    }

    [TreeNode] AddNode([IRenderable]$renderable) {
        $node = [TreeNode]::new($renderable)
        $this.Nodes.Add($node)
        return $node
    }

    [TreeNode] AddNode([string]$text) {
        return $this.AddNode([Markup]::new($text))
    }
}

class Tree : IRenderable {
    hidden [TreeNode]$_root
    [TreeNode]$Root
    [TreeGuide]$Guide
    [Style]$Style

    Tree([IRenderable]$renderable) {
        $this._root = [TreeNode]::new($renderable)
        $this.Root = $this._root
        $this.Guide = [TreeGuide]::get_Line()
        $this.Style = [Style]::Plain
    }

    Tree([string]$label) {
        $this._root = [TreeNode]::new([Markup]::new($label))
        $this.Root = $this._root
        $this.Guide = [TreeGuide]::get_Line()
        $this.Style = [Style]::Plain
    }

    [List[TreeNode]] get_Nodes() { return $this._root.Nodes }

    [TreeNode] AddNode([IRenderable]$renderable) {
        return $this._root.AddNode($renderable)
    }

    [TreeNode] AddNode([string]$text) {
        return $this._root.AddNode($text)
    }

    [Measurement] Measure([RenderOptions]$options, [int]$maxWidth) {
        $safeGuide = [TreeGuide]::GetSafeTreeGuide($options, $this.Guide)
        $guideWidth = [Cell]::GetCellLength($safeGuide.GetPart([TreeGuidePart]::End))
        $measurements = [List[Measurement]]::new()
        $this.CollectMeasurements($this._root, $measurements, 0, $guideWidth, $options, $maxWidth)

        if ($measurements.Count -eq 0) {
            return [Measurement]::new(0, 0)
        }

        $min = 0
        $max = 0
        foreach ($measurement in $measurements) {
            if ($measurement.Min -gt $min) { $min = $measurement.Min }
            if ($measurement.Max -gt $max) { $max = $measurement.Max }
        }

        return [Measurement]::new([Math]::Min($min, $maxWidth), [Math]::Min($max, $maxWidth))
    }

    [object[]] Render([RenderOptions]$options, [int]$maxWidth) {
        $result = [List[Segment]]::new()
        $visited = [HashSet[int]]::new()
        $this.RenderNode($this._root, $options, $maxWidth, [string[]]@(), $true, $visited, $result)

        while ($result.Count -gt 0 -and $result[$result.Count - 1].IsLineBreak) {
            $result.RemoveAt($result.Count - 1)
        }

        return $result.ToArray()
    }

    hidden [void] CollectMeasurements([TreeNode]$node, [List[Measurement]]$measurements, [int]$depth, [int]$guideWidth, [RenderOptions]$options, [int]$maxWidth) {
        if ($null -eq $node) {
            return
        }

        $prefixWidth = $depth * $guideWidth
        $availableWidth = [Math]::Max(1, $maxWidth - $prefixWidth)
        $measurement = $node.Renderable.Measure($options, $availableWidth)
        $measurements.Add([Measurement]::new($measurement.Min + $prefixWidth, $measurement.Max + $prefixWidth))

        if ($node.Expanded) {
            foreach ($child in $node.Nodes) {
                $this.CollectMeasurements($child, $measurements, $depth + 1, $guideWidth, $options, $maxWidth)
            }
        }
    }

    hidden [void] RenderNode([TreeNode]$node, [RenderOptions]$options, [int]$maxWidth, [string[]]$prefixParts, [bool]$isLast, [HashSet[int]]$visited, [List[Segment]]$result) {
        if ($null -eq $node) {
            return
        }

        $nodeId = [Runtime.CompilerServices.RuntimeHelpers]::GetHashCode($node)
        if (!$visited.Add($nodeId)) {
            throw [InvalidOperationException]::new('Cycle detected in tree.')
        }

        $prefix = [List[Segment]]::new()
        foreach ($part in $prefixParts) {
            $prefix.Add([Segment]::new($part, $this.Style))
        }

        $prefixWidth = [Segment]::CellCount($prefix)
        $availableWidth = [Math]::Max(1, $maxWidth - $prefixWidth)
        $lines = [Segment]::SplitLines($node.Renderable.Render($options, $availableWidth), $availableWidth)
        if ($lines.Count -eq 0) {
            $lines = [List[SegmentLine]]::new()
            $lines.Add([SegmentLine]::new())
        }

        for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
            if ($prefix.Count -gt 0) {
                $result.AddRange($prefix)
            }

            $result.AddRange($lines[$lineIndex].Segments)
            $result.Add([Segment]::LineBreak)

            if ($lineIndex -eq 0 -and $prefixParts.Length -gt 0) {
                $continuationParts = [string[]]$prefixParts.Clone()
                $continuationParts[$continuationParts.Length - 1] = $this.GetGuide($options, $isLast ? [TreeGuidePart]::Space : [TreeGuidePart]::Continue).Text
                $prefix = [List[Segment]]::new()
                foreach ($part in $continuationParts) {
                    $prefix.Add([Segment]::new($part, $this.Style))
                }
            }
        }

        if (!$node.Expanded -or $node.Nodes.Count -eq 0) {
            return
        }

        for ($index = 0; $index -lt $node.Nodes.Count; $index++) {
            $child = $node.Nodes[$index]
            $childIsLast = ($index -eq $node.Nodes.Count - 1)
            $childPrefix = [List[string]]::new()
            $childPrefix.AddRange($prefixParts)
            if ($prefixParts.Length -gt 0) {
                $childPrefix[$childPrefix.Count - 1] = $this.GetGuide($options, $isLast ? [TreeGuidePart]::Space : [TreeGuidePart]::Continue).Text
            }
            $childPrefix.Add($this.GetGuide($options, $childIsLast ? [TreeGuidePart]::End : [TreeGuidePart]::Fork).Text)
            $this.RenderNode($child, $options, $maxWidth, $childPrefix.ToArray(), $childIsLast, $visited, $result)
        }
    }

    hidden [Segment] GetGuide([RenderOptions]$options, [TreeGuidePart]$part) {
        $safeGuide = [TreeGuide]::GetSafeTreeGuide($options, $this.Guide)
        $styleToUse = if ($null -ne $this.Style) { $this.Style } else { [Style]::Plain }
        return [Segment]::new($safeGuide.GetPart($part), $styleToUse)
    }
}