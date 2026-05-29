## run multiple jobs in parallel:
$Jobs = [BackgroundJob[]](
  @{
    Name        = "Compute Primes"
    ScriptBlock = {
      param($count)
      $primes = @(2)
      $n = 3
      while ($primes.Count -lt $count) {
        $isPrime = $true
        foreach ($p in $primes) {
          if (($p * $p) -gt $n) { break }
          if ($n % $p -eq 0) {
            $isPrime = $false
            break
          }
        }
        if ($isPrime) { $primes += $n }
        $n += 2
      }
      return @{
        Count     = $primes.Count
        LastPrime = $primes[-1]
      }
    }
    Arguments   = @(2500)
  },
  @{
    Name        = "Simulate File Processing"
    ScriptBlock = {
      param($fileCount)
      $files = @()
      for ($i = 1; $i -le $fileCount; $i++) {
        $files += "file_$i.txt"
        Start-Sleep -Milliseconds 60
      }
      return @{
        Processed = $files.Count
        Files     = $files[0..3]
      }
    }
    Arguments   = @(30)
  },
  @{
    Name        = "Simulate API Calls"
    ScriptBlock = {
      param($callCount)
      $results = @()
      for ($i = 1; $i -le $callCount; $i++) {
        $results += @{
          Call    = $i
          Status  = "Success"
          Latency = Get-Random -Minimum 50 -Maximum 200
        }
        Start-Sleep -Milliseconds 100
      }
      return $results
    }
    Arguments   = @(15)
  },
  @{
    n = "Data Analysis"
    s = {
      param($iterations)
      $data = @()
      $sum = 0
      for ($i = 1; $i -le $iterations; $i++) {
        $value = Get-Random -Minimum 1 -Maximum 100
        $data += $value
        $sum += $value
        Start-Sleep -Milliseconds 20
      }
      $avg = $sum / $data.Count
      return @{
        TotalRecords = $data.Count
        Average      = [Math]::Round($avg, 2)
      }
    }
    a = @(100)
    t = $false
  },
  @{
    Name        = "DB Operations (Fails)"
    ScriptBlock = {
      param($operationCount)
      Start-Sleep -Milliseconds 500
      throw "Connection to database failed randomly."
    }
    Arguments   = @(15)
  }
)

return [ThreadRunner]::Run("Doing epic stuff in the background...", $Jobs)
