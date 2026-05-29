function Start-ProcessMonitor {
  # .SYNOPSIS
  # Monitor process start/stop events
  # .DESCRIPTION
  # Monitors specified processes and reports when they start or stop running.
  # .EXAMPLE
  # Get-Process | Start-ProcessMonitor
  # .PARAMETER Process
  # One or more Process objects to monitor (accepts pipeline input).
  [CmdletBinding()]
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    "PSUseShouldProcessForStateChangingFunctions", "",
    Justification = "Not changing state")]
  [Alias('Monitor-Process')]
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [System.Diagnostics.Process] $Process
  )

  begin {
    $monitor = [ProcessMonitor]::new()
    $monitor.StartTimer()
  }

  process {
    $monitor.Track($Process)
  }

  end {
    Write-Host "Monitoring started. Press Ctrl+C to stop." -ForegroundColor Cyan

    try {
      while ($true) { Start-Sleep -Seconds 1 }
    } finally {
      $monitor.Stop()
    }
  }
}