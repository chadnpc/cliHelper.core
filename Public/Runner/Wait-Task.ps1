function Wait-Task {
  #.DESCRIPTION
  #  Waits for a scriptblock or job to complete, displaying a live spinner.
  #  WaitJob now returns [Results] — a structured wrapper around success/failure/output.
  #.EXAMPLE
  #  Wait-Task "Running" { Param($ob) Start-Sleep -Seconds 3; return $ob } (Get-Process pwsh)
  #.EXAMPLE
  #  # Get the full Results object for error inspection:
  #  $res = Wait-Task "Fetching" { Invoke-RestMethod https://api.example.com } -PassThru
  #  if ($res.HasErrors) { $res.Errors | ForEach-Object { Write-Warning $_ } }
  #.PARAMETER ProgressMsg
  #  Message to display while waiting (supports Spectre markup e.g. '[green]Loading[/]')
  #.PARAMETER ScriptBlock
  #  Scriptblock to run as a background thread job
  #.PARAMETER Job
  #  An already-started Job to wait on
  #.PARAMETER ArgumentList
  #  Arguments forwarded to the scriptblock
  #.PARAMETER PassThru
  #  Return the raw [Results] object instead of unwrapping the output payload
  #.OUTPUTS
  #  [PsObject] (or [Results] when -PassThru is used)
  [CmdletBinding(DefaultParameterSetName = 'ScriptBlock')]
  [OutputType([PsObject])][Alias('await')]
  Param (
    [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'Job')]
    [Parameter(Mandatory = $false, Position = 0, ParameterSetName = 'ScriptBlock')]
    [Alias('m')][ValidateNotNullOrEmpty()]
    [string]$ProgressMsg = 'Waiting',

    [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'ScriptBlock')]
    [Alias('s')][ValidateNotNullOrEmpty()]
    [scriptblock]$ScriptBlock,

    [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'Job')]
    [Alias('j')][ValidateNotNullOrEmpty()]
    [System.Management.Automation.Job]$Job,

    [Parameter(Mandatory = $false, Position = 2, ParameterSetName = 'ScriptBlock')]
    [Object[]]$ArgumentList = $null,

    [Parameter(Mandatory = $false)]
    [switch]$PassThru
  )
  begin {
    [Results]$results = $null
  }
  process {
    if ($PSCmdlet.ParameterSetName -eq 'ScriptBlock') {
      $results = [ProgressUtil]::WaitJob($ProgressMsg, $ScriptBlock, $ArgumentList)
    } else {
      $results = [ProgressUtil]::WaitJob($ProgressMsg, $Job)
    }
  }
  end {
    if ($PassThru) {
      return $results
    }
    if ($results.HasErrors) {
      foreach ($err in $results.Errors) {
        Write-Error $err -ErrorAction Continue
      }
    }
    return $results.Output
  }
}
