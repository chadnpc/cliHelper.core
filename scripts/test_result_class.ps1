#Requires -Version 5.1
<#
.SYNOPSIS
    Usage examples and patterns for Result.psm1
#>

# ═══════════════════════════════════════════════════════════════════
#  1. BASIC CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════

$ok = [Result]::Ok(42)
$okVoid = [Result]::Ok()               # unit / void Ok
$err = [Result]::Err("bad input")

Write-Host $ok       # Ok(42)
Write-Host $okVoid   # Ok(void)
Write-Host $err      # Err(bad input)

# ═══════════════════════════════════════════════════════════════════
#  2. EXTRACTION
# ═══════════════════════════════════════════════════════════════════

$ok.Unwrap()                           # 42
$ok.Expect("should have a value")      # 42
$err.UnwrapOr(0)                       # 0
$err.UnwrapOrElse({ param($e) -1 })    # -1
$err.UnwrapOrDefault()                 # $null

# ═══════════════════════════════════════════════════════════════════
#  3. PATTERN MATCH  (preferred over bare switch blocks)
# ═══════════════════════════════════════════════════════════════════

$label = $ok.Match(
  { param($v) "Value is $v" },
  { param($e) "Error: $e" }
)
# "Value is 42"

# ═══════════════════════════════════════════════════════════════════
#  4. MAPPING
# ═══════════════════════════════════════════════════════════════════

$doubled = $ok.Map({ param($x) $x * 2 })            # Ok(84)
$errPassed = $err.Map({ param($x) $x * 2 })           # Err("bad input") — unchanged

$friendly = $err.MapErr({ param($e) "User-friendly: $e" })
# Err("User-friendly: bad input")

$safe = $ok.MapOr(-1, { param($x) $x + 8 })          # 50
$safe = $err.MapOr(-1, { param($x) $x + 8 })         # -1

# ═══════════════════════════════════════════════════════════════════
#  5. CHAINING
# ═══════════════════════════════════════════════════════════════════

function Divide-Safely ([int]$a, [int]$b) {
  if ($b -eq 0) { return [Result]::Err("Division by zero") }
  return [Result]::Ok([math]::Floor($a / $b))
}

$result = [Result]::Ok(100) |
  ForEach-Object { $_.AndThen({ param($x) Divide-Safely $x 4 }) } |
  ForEach-Object { $_.AndThen({ param($x) Divide-Safely $x 5 }) } |
  ForEach-Object { $_.Map(    { param($x) "Result: $x" }) }
# Ok("Result: 5")

# Short-circuits on first Err
$short = [Result]::Ok(100) |
  ForEach-Object { $_.AndThen({ param($x) Divide-Safely $x 0 }) } | # Err here
  ForEach-Object { $_.AndThen({ param($x) Divide-Safely $x 5 }) }     # skipped
# Err("Division by zero")

# ═══════════════════════════════════════════════════════════════════
#  6. FLATTEN  (Result<Result<T>> → Result<T>)
# ═══════════════════════════════════════════════════════════════════

$nested = [Result]::Ok([Result]::Ok(99))
$flat = $nested.Flatten()      # Ok(99)

$nestedErr = [Result]::Ok([Result]::Err("inner error"))
$flatErr = $nestedErr.Flatten() # Err("inner error")

# ═══════════════════════════════════════════════════════════════════
#  7. INSPECTION  (side-effects, does NOT break the chain)
# ═══════════════════════════════════════════════════════════════════

[Result]::Ok("payload") |
  ForEach-Object {
    $_.Inspect(
      { param($v) Write-Host "Got: $v" -ForegroundColor Cyan }
    ).Map(
      { param($v) $v.ToUpper() }
    ).InspectErr(
      { param($e) Write-Host "Error: $e" -ForegroundColor Red }
    )
  }
# Console: "Got: payload"
# Result:  Ok("PAYLOAD")

# ═══════════════════════════════════════════════════════════════════
#  8. STATE PREDICATES
# ═══════════════════════════════════════════════════════════════════

$ok.IsOkAnd({ param($v) $v -gt 10 })    # $true
$ok.IsOkAnd({ param($v) $v -gt 99 })    # $false
$err.IsErrAnd({ param($e) $e -is [string] }) # $true

# ═══════════════════════════════════════════════════════════════════
#  9. OR / OR-ELSE (fallback chains)
# ═══════════════════════════════════════════════════════════════════

$fallback = [Result]::Err("primary") |
  ForEach-Object { $_.Or([Result]::Ok("fallback")) }
# Ok("fallback")

$computed = [Result]::Err("404") |
  ForEach-Object {
    $_.OrElse({
        param($e)
        if ($e -eq "404") { return [Result]::Ok("default page") }
        return [Result]::Err($e)
      })
  }
# Ok("default page")

# ═══════════════════════════════════════════════════════════════════
#  10. EQUALITY & HASHING  (safe to use as Hashtable keys)
# ═══════════════════════════════════════════════════════════════════

[Result]::Ok(42) -eq [Result]::Ok(42)   # $true
[Result]::Ok(1) -eq [Result]::Ok(2)    # $false

$cache = @{}
$cache[[Result]::Ok("key")] = "cached"
$cache[[Result]::Ok("key")]              # "cached" — GetHashCode is consistent

# ═══════════════════════════════════════════════════════════════════
#  11. INVOKE-SAFELY  (non-terminating errors also caught)
# ═══════════════════════════════════════════════════════════════════

# Without -ErrorAction Stop, Get-Content writes a non-terminating error
# that a plain try/catch would MISS. Invoke-Safely sets EAP=Stop internally.
$r = Invoke-Safely { Get-Content 'nonexistent.txt' }
# Err(System.Management.Automation.ItemNotFoundException)

$content = $r.UnwrapOr("default content")

# Map the exception to a friendly string
$r2 = Invoke-Safely { Get-Content 'nonexistent.txt' } -ErrorMapper {
  param($e) "Could not read file: $($e.Message)"
}

# ═══════════════════════════════════════════════════════════════════
#  12. MERGE-RESULTS  (collect pipeline of Results)
# ═══════════════════════════════════════════════════════════════════

# All succeed
$combined = 1..5 |
  ForEach-Object { [Result]::Ok($_ * 10) } |
  Merge-Results
# Ok(@(10, 20, 30, 40, 50))

# One failure → first Err propagated
$combined = @(
  [Result]::Ok(1),
  [Result]::Err("step 2 failed"),
  [Result]::Ok(3)
) | Merge-Results
# Err("step 2 failed")

# ═══════════════════════════════════════════════════════════════════
#  13. SPLIT-RESULTS  (partition successes and failures)
# ═══════════════════════════════════════════════════════════════════

$parts = @(
  [Result]::Ok(1),
  [Result]::Err("x"),
  [Result]::Ok(2),
  [Result]::Err("y")
) | Split-Results

$parts.Ok   # 1, 2
$parts.Err  # "x", "y"

# ═══════════════════════════════════════════════════════════════════
#  14. REALISTIC PIPELINE — config loading
# ═══════════════════════════════════════════════════════════════════

function Read-ConfigFile ([string]$path) {
  Invoke-Safely { Get-Content $path -Raw } -ErrorMapper {
    param($e) "Cannot read '$path': $($e.Message)"
  }
}

function Parse-Config ([string]$json) {
  Invoke-Safely { $json | ConvertFrom-Json } -ErrorMapper {
    param($e) "Invalid JSON: $($e.Message)"
  }
}

function Validate-Config ($cfg) {
  if (-not $cfg.PSObject.Properties['apiKey']) {
    return [Result]::Err("Config missing required field: apiKey")
  }
  return [Result]::Ok($cfg)
}

$apiKey = Read-ConfigFile 'config.json' |
  ForEach-Object { $_.AndThen({ param($raw) Parse-Config $raw }) } |
  ForEach-Object { $_.AndThen({ param($cfg) Validate-Config $cfg }) } |
  ForEach-Object { $_.Map(    { param($cfg) $cfg.apiKey }) }

$apiKey.Match(
  { param($k) Write-Host "API key loaded: $k" },
  { param($e) Write-Host "Config error: $e" -ForegroundColor Red }
)
