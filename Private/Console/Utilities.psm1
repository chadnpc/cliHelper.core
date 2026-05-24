using module .\Enums.psm1
using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Text

class SystemConsoleExtensions {
}

class EnumerableExtensions {
  static [object[]] EmptyIfNull([IEnumerable]$items) {
    if ($null -eq $items) {
      return [object[]]@()
    }

    $result = [List[object]]::new()
    foreach ($item in $items) {
      $result.Add($item)
    }
    return $result.ToArray()
  }

  static [bool] HasItems([IEnumerable]$items) {
    if ($null -eq $items) {
      return $false
    }

    foreach ($item in $items) {
      return $true
    }

    return $false
  }
}

class EnumUtils {
  static [string[]] GetNames([Type]$enumType) {
    return [Enum]::GetNames($enumType)
  }
}

class StringBuffer : IDisposable {
  hidden [StringBuilder]$_builder
  hidden [bool]$_disposed

  StringBuffer() {
    $this._builder = [StringBuilder]::new()
    $this._disposed = $false
  }

  [void] Write([string]$text) {
    if ($this._disposed) {
      throw [ObjectDisposedException]::new('StringBuffer')
    }

    if ($null -ne $text) {
      [void]$this._builder.Append($text)
    }
  }

  [void] WriteLine() {
    $this.WriteLine([string]::Empty)
  }

  [void] WriteLine([string]$text) {
    if ($this._disposed) {
      throw [ObjectDisposedException]::new('StringBuffer')
    }

    if ($null -ne $text) {
      [void]$this._builder.Append($text)
    }
    [void]$this._builder.AppendLine()
  }

  [void] Clear() {
    if ($this._disposed) {
      throw [ObjectDisposedException]::new('StringBuffer')
    }

    [void]$this._builder.Clear()
  }

  [string] ToString() {
    if ($this._disposed) {
      throw [ObjectDisposedException]::new('StringBuffer')
    }

    return $this._builder.ToString()
  }

  [void] Dispose() {
    $this._disposed = $true
    $this._builder = [StringBuilder]::new()
  }
}

class StringExtensions {
  static [string] Repeat([string]$text, [int]$count) {
    if ([string]::IsNullOrEmpty($text) -or $count -le 0) {
      return [string]::Empty
    }

    return [string]::Concat((1..$count | ForEach-Object { $text }))
  }

  static [string] NullIfWhiteSpace([string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) {
      return $null
    }

    return $text
  }
}

class TextWriterExtensions {
}

class EmbeddedResourceReader {
}

class ExceptionInfoResolver {
}

class ExceptionScrubber : ExceptionInfoResolver {
}

class FakeTimeProvider : TimeProvider {
}

class FigletReportGenerator {
}

class GitHubIssueAttribute : Attribute {
}

class ModuleInitializerAttribute : Attribute {
}