using module .\Enums.psm1
<#
.NOTES
      Ok(value)  — successful computation carrying a value
      Err(error) — failed computation carrying an error descriptor

    Thread-safety
    ─────────────
    Result instances are fully IMMUTABLE after construction (no public setters,
    all mutation methods return new objects). They are safe to share across
    PowerShell Runspaces / Thread-jobs without locks.

    Scriptblock callbacks (Map, AndThen, etc.) are NOT automatically thread-safe —
    that responsibility lies with the caller.

    Compatibility
    ─────────────
    GetHashCode : Uses a manual XOR combiner compatible with PS 5.1 and PS 7+.
    Null-safety : Err() rejects $null errors by design — use Err("reason") or
                  Err([ErrorRecord]) rather than Err($null).

    Known PS class limitations
    ──────────────────────────
    • PS classes have no enforced private members at runtime — 'hidden' prevents
      tab-completion leakage but does not stop determined callers.
    • No generic type parameters — Ok/Err values are typed [object]; add your own
      validation in callbacks when strict typing matters.
#>
class Result {
  # ── Immutable internal state
  hidden [ResultKind] $_kind
  hidden [object]     $_value   # populated when Ok
  hidden [object]     $_error   # populated when Err

  # Private constructor ─ always go through the static factories
  hidden Result([ResultKind]$kind, [object]$value, [object]$ErrorRecord) {
    $this._kind = $kind
    $this._value = $value
    $this._error = $ErrorRecord
  }

  # Ok carrying a value
  static [Result] Ok([object]$value) {
    return [Result]::new([ResultKind]::Ok, $value, $null)
  }

  # Ok carrying no value (unit / void)
  static [Result] Ok() {
    return [Result]::new([ResultKind]::Ok, $null, $null)
  }

  # Err carrying an error descriptor (non-null required)
  static [Result] Err([object]$ErrorRecord) {
    # indistinguishable Err and hides programming mistakes.
    if ($null -eq $error) {
      throw [System.ArgumentNullException]::new(
        'error',
        "Err() requires a non-null error value. " +
        "Use a descriptive string, Exception, or ErrorRecord."
      )
    }
    return [Result]::new([ResultKind]::Err, $null, $ErrorRecord)
  }

  #  State Queries
  [bool] IsOk() { return $this._kind -eq [ResultKind]::Ok }
  [bool] IsErr() { return $this._kind -eq [ResultKind]::Err }

  [bool] IsOkAnd([scriptblock]$predicate) {
    if ($null -eq $predicate) { throw [System.ArgumentNullException]::new('predicate') }
    if ($this.IsErr()) { return $false }
    try { return [bool](& $predicate $this._value) }
    catch { return $false }
  }

  [bool] IsErrAnd([scriptblock]$predicate) {
    if ($null -eq $predicate) { throw [System.ArgumentNullException]::new('predicate') }
    if ($this.IsOk()) { return $false }
    try { return [bool](& $predicate $this._error) }
    catch { return $false }
  }
  #  Extraction
  # Returns the Ok value; throws on Err with the error's message.
  [object] Unwrap() {
    if ($this.IsErr()) {
      throw [System.InvalidOperationException]::new(
        "Called Unwrap() on an Err value: $($this._error)"
      )
    }
    return $this._value
  }

  # Returns the Ok value; throws on Err with a caller-supplied message.
  [object] Expect([string]$message) {
    if ([string]::IsNullOrWhiteSpace($message)) {
      throw [System.ArgumentException]::new(
        'Expect() message must not be null or blank.', 'message')
    }
    if ($this.IsErr()) {
      throw [System.InvalidOperationException]::new(
        "${message}: $($this._error)"
      )
    }
    return $this._value
  }

  # Returns the Err value; throws if Ok.
  [object] UnwrapErr() {
    if ($this.IsOk()) {
      throw [System.InvalidOperationException]::new(
        "Called UnwrapErr() on an Ok value: $($this._value)"
      )
    }
    return $this._error
  }

  # Returns the Err value; throws with caller-supplied message if Ok.
  [object] ExpectErr([string]$message) {
    if ([string]::IsNullOrWhiteSpace($message)) {
      throw [System.ArgumentException]::new(
        'ExpectErr() message must not be null or blank.', 'message')
    }
    if ($this.IsOk()) {
      throw [System.InvalidOperationException]::new(
        "${message}: $($this._value)"
      )
    }
    return $this._error
  }

  # Returns the Ok value or $default when Err.
  [object] UnwrapOr([object]$default) {
    if ($this.IsOk()) { return $this._value }
    return $default
  }

  # Returns the Ok value, or the result of $fn called with the error.
  [object] UnwrapOrElse([scriptblock]$fn) {
    if ($null -eq $fn) { throw [System.ArgumentNullException]::new('fn') }
    if ($this.IsOk()) { return $this._value }
    try {
      return & $fn $this._error
    } catch {
      throw [System.InvalidOperationException]::new(
        "UnwrapOrElse callback threw: $($_.Exception.Message)",
        $_.Exception
      )
    }
  }

  # Returns Ok value or $null — no arguments needed.
  [object] UnwrapOrDefault() {
    if ($this.IsOk()) { return $this._value }
    return $null
  }

  # Mapping
  # Transform the Ok value; pass Err through unchanged.
  [Result] Map([scriptblock]$fn) {
    if ($null -eq $fn) { throw [System.ArgumentNullException]::new('fn') }
    if ($this.IsErr()) { return $this }     # short-circuit, no allocation
    try {
      return [Result]::Ok($(& $fn $this._value))
    } catch {
      return [Result]::Err($_.Exception)
    }
  }

  # Map the Ok value through $fn; return $default on Err.
  [object] MapOr([object]$default, [scriptblock]$fn) {
    if ($null -eq $fn) { throw [System.ArgumentNullException]::new('fn') }
    if ($this.IsErr()) { return $default }
    try { return & $fn $this._value }
    catch { return $default }
  }

  # Map Ok through $fn; compute default via $defaultFn on Err.
  [object] MapOrElse([scriptblock]$defaultFn, [scriptblock]$fn) {
    if ($null -eq $defaultFn) { throw [System.ArgumentNullException]::new('defaultFn') }
    if ($null -eq $fn) { throw [System.ArgumentNullException]::new('fn') }
    if ($this.IsErr()) {
      try { return & $defaultFn $this._error }
      catch {
        throw [System.InvalidOperationException]::new(
          "MapOrElse defaultFn threw: $($_.Exception.Message)", $_.Exception)
      }
    }
    try { return & $fn $this._value }
    catch {
      throw [System.InvalidOperationException]::new(
        "MapOrElse fn threw: $($_.Exception.Message)", $_.Exception)
    }
  }

  # Transform the Err value; pass Ok through unchanged.
  [Result] MapErr([scriptblock]$fn) {
    if ($null -eq $fn) { throw [System.ArgumentNullException]::new('fn') }
    if ($this.IsOk()) { return $this }
    try {
      $mapped = & $fn $this._error
      if ($null -eq $mapped) {
        throw [System.InvalidOperationException]::new(
          "MapErr callback returned null — Err() requires a non-null error.")
      }
      return [Result]::Err($mapped)
    } catch [System.InvalidOperationException] { throw }   # re-throw our own
    catch {
      return [Result]::Err($_.Exception)
    }
  }

  # If Ok, call $fn with value and return its Result; propagate Err.
  [Result] AndThen([scriptblock]$fn) {
    if ($null -eq $fn) { throw [System.ArgumentNullException]::new('fn') }
    if ($this.IsErr()) { return $this }
    try {
      $next = & $fn $this._value
      if ($next -isnot [Result]) {
        $typeName = if ($null -ne $next) { $next.GetType().FullName } else { 'null' }
        return [Result]::Err(
          [System.InvalidOperationException]::new(
            "AndThen callback must return [Result]; got [$typeName]"
          )
        )
      }
      return $next
    } catch {
      return [Result]::Err($_.Exception)
    }
  }

  # If Ok return $other; otherwise propagate this Err.
  [Result] And([Result]$other) {
    if ($null -eq $other) { throw [System.ArgumentNullException]::new('other') }
    if ($this.IsOk()) { return $other }
    return $this
  }

  # If Ok return self; otherwise return $other.
  [Result] Or([Result]$other) {
    if ($null -eq $other) { throw [System.ArgumentNullException]::new('other') }
    if ($this.IsOk()) { return $this }
    return $other
  }

  # If Ok return self; otherwise call $fn with the error and return its Result.
  [Result] OrElse([scriptblock]$fn) {
    if ($null -eq $fn) { throw [System.ArgumentNullException]::new('fn') }
    if ($this.IsOk()) { return $this }
    try {
      $next = & $fn $this._error
      if ($next -isnot [Result]) {
        $typeName = if ($null -ne $next) { $next.GetType().FullName } else { 'null' }
        return [Result]::Err(
          [System.InvalidOperationException]::new(
            "OrElse callback must return [Result]; got [$typeName]"
          )
        )
      }
      return $next
    } catch {
      return [Result]::Err($_.Exception)
    }
  }

  # Flatten Result<Result<T>> → Result<T>.
  # If the Ok value is itself a Result, unwrap one layer.
  [Result] Flatten() {
    if ($this.IsErr()) { return $this }
    if ($this._value -is [Result]) { return [Result]$this._value }
    return $this   # already flat
  }


  #  Inspection (side-effects only — never alter the Result)
  #      Side-effect callbacks must never alter flow — exceptions are silenced.
  #      Log internally if you need to debug a bad inspector.
  [Result] Inspect([scriptblock]$fn) {
    if ($null -eq $fn) { throw [System.ArgumentNullException]::new('fn') }
    if ($this.IsOk()) {
      try { & $fn $this._value | Out-Null } catch {
        $null
      }
    }
    return $this
  }

  [Result] InspectErr([scriptblock]$fn) {
    if ($null -eq $fn) { throw [System.ArgumentNullException]::new('fn') }
    if ($this.IsErr()) {
      try { & $fn $this._error | Out-Null } catch {
        $null
      }
    }
    return $this
  }

  # Pattern matching
  # Exhaustive two-armed match — always produces a value, never silently
  #      falls through.  Preferred over bare switch($result.IsOk()) blocks.
  #
  #  Example:
  #    $label = $result.Match(
  #        { param($v) "Success: $v" },
  #        { param($e) "Failed:  $e" }
  #    )
  [object] Match([scriptblock]$onOk, [scriptblock]$onErr) {
    if ($null -eq $onOk) { throw [System.ArgumentNullException]::new('onOk') }
    if ($null -eq $onErr) { throw [System.ArgumentNullException]::new('onErr') }
    if ($this.IsOk()) { return & $onOk $this._value }
    else { return & $onErr $this._error }
  }


  #  Conversion


  # Ok → value ; Err → $null
  [object] ToNullable() {
    if ($this.IsOk()) { return $this._value }
    return $null
  }

  # Ok → @(value) ; Err → @()
  [array] ToArray() {
    if ($this.IsOk()) { return @($this._value) }
    return @()
  }


  #  objects that are Equal must have the same hash. That breaks Hashtable /
  #  Dictionary / GroupBy etc.)

  [bool] Equals([object]$other) {
    if ($null -eq $other -or -not ($other -is [Result])) { return $false }
    $r = [Result]$other
    if ($this._kind -ne $r._kind) { return $false }
    if ($this.IsOk()) {
      if ($null -eq $this._value -and $null -eq $r._value) { return $true }
      if ($null -eq $this._value -or $null -eq $r._value) { return $false }
      return $this._value.Equals($r._value)
    }
    if ($null -eq $this._error -and $null -eq $r._error) { return $true }
    if ($null -eq $this._error -or $null -eq $r._error) { return $false }
    return $this._error.Equals($r._error)
  }

  # Djb2-style combiner — compatible with PS 5.1 (.NET 4.x) and PS 7+.
  [int] GetHashCode() {
    $inner = if ($this.IsOk()) { $this._value } else { $this._error }
    $innerHash = if ($null -eq $inner) { 0 } else { $inner.GetHashCode() }
    # Combine kind hash + inner hash
    $kindHash = $this._kind.GetHashCode()
    return (($kindHash -shl 5) + $kindHash) -bxor $innerHash
  }

  [string] ToString() {
    if ($this.IsOk()) {
      $inner = if ($null -eq $this._value) { 'void' } else { $this._value.ToString() }
      return "Ok($inner)"
    }
    # Err side — _error should never be null (factory enforces it) but guard anyway
    $inner = if ($null -eq $this._error) { '???' } else { $this._error.ToString() }
    return "Err($inner)"
  }
}

class Results {
  hidden [System.Collections.Generic.List[object]] $_items
  [double]$ElapsedTime
  [bool]$IsSuccess
  [bool]$HasErrors
  [object[]]$Output
  [object[]]$Errors
  [int]$Count

  Results() {
    $this._items = [System.Collections.Generic.List[object]]::new()
    $this.ElapsedTime = 0
    $this.IsSuccess = $false
    $this.HasErrors = $false
    $this.Output = @()
    $this.Errors = @()
    $this.Count = 0
  }

  [void] Add([Result]$result, [double]$elapsedTime) {
    $this._items.Add([PSCustomObject]@{
        Result      = $result
        ElapsedTime = $elapsedTime
      }
    )
    $this.ElapsedTime = [math]::Round($this.ElapsedTime + $elapsedTime, 2)

    if ($result.IsOk()) {
      $this.IsSuccess = $true
      $val = $result.Unwrap()
      if ($null -ne $val) {
        if ($val -is [array]) { $this.Output += $val }
        else { $this.Output += @($val) }
      }
    } else {
      $this.HasErrors = $true
      $this.Errors += @($result.UnwrapErr())
    }
    $this.Count = $this._items.Count
  }
}