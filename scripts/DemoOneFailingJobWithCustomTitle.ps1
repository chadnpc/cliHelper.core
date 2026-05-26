Import-Module .\cliHelper.core.psd1 -Verbose:$false -Force
$failed = $false
try {
  [ThreadRunner]::Run("doing a failing task in the background...", @{
      n           = "[yellow]run fake db operations[/]"
      s           = {
        param($operationCount)
        Start-Sleep -Milliseconds 4000
        throw "idk wtf just happened!"
      }
      a           = 15
      ThrowOnFail = $false
    }
  )
} catch {
  $failed = $true
  Write-Host "An error occurred. (Message: $($_.Exception.Message))" -ForegroundColor Red
} finally {
  if ($failed) {
    Write-Host "The command failed." -ForegroundColor Red
    $Error[0] | Format-List * -Force
  } else {
    Write-Host "The command completed successfully." -ForegroundColor Green
  }
}