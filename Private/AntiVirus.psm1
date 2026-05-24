
using namespace System
using namespace System.IO
using namespace System.Runtime.InteropServices
using namespace System.Threading

using module .\Enums.psm1
using module .\COMInterop.psm1

class AVScanResult : System.IComparable, System.IEquatable[Object] {
  [bool]$Passed
  [int]$ErrorCode
  [string]$EngineName
  [AVScanResultType]$ResType = "VirusNotFound"
  [AllowNull()][string]$AdditionalMessage

  AVScanResult() {}
  AVScanResult([AVScanResultType]$ResType) {
    $this.ResType = $ResType
  }

  # Override base Object.Equals
  [bool] Equals([object]$obj) {
    if ($null -eq $obj) { return $false }
    if ($obj -is [AVScanResult]) {
      return $this.ErrorCode -eq $obj.ErrorCode
    }
    return $false
  }
  # Override GetHashCode
  [int] GetHashCode() {
    return $this.ResType.GetHashCode()
  }
  [Int] CompareTo($rhs) {
    if ($rhs -isnot [AVScanResult]) {
      throw "NotIcomparable"
    } else {
      return $this.GetHashCode() - $rhs.GetHashCode()
    }
  }
  [string] ToString() {
    return $this.ResType.ToString()
  }
}

# ---------------------------------------------------------------------------
# AVScanner
# ---------------------------------------------------------------------------
# Wraps the Windows IAttachmentExecute COM API to scan a file with whatever
# antivirus product is installed on the local machine (Windows Defender, etc.).
#
# Requirements:
#   - Windows OS (7+)
#   - An installed AV product that supports the IAttachmentExecute COM API
#
# Usage:
#   $scanner = [AvScanner]::new()
#   $result  = $scanner.ScanAndClean("C:\path\to\file.exe")
#   # $result is an [AVScanResultType]: VirusNotFound | VirusFound | FileNotExist | BlockedByPolicy
#
# ---------------------------------------------------------------------------

class AvScanner {
  ## The client GUID registered with the IAttachmentExecute API.
  [Guid]$ClientGuid
  AvScanner() {
    ## Initializes Scanner with the default AntiVirusScanner project GUID.
    $this.ClientGuid = [Guid]::new("{C467440F-8ACB-449B-A7B1-05B7405C3753}")
  }

  ## Initializes Scanner with a custom GUID.
  AvScanner([Guid]$clientGuid) {
    $this.ClientGuid = $clientGuid
  }

  ## Initializes Scanner from a GUID string.
  AvScanner([string]$clientGuidString) {
    $this.ClientGuid = [Guid]::new($clientGuidString)
  }

  # -------------------------------------------------------------------------
  # Public methods
  # -------------------------------------------------------------------------

  ## Scans the specified file and attempts to clean it if infected.
  ## Returns [AVScanResultType]: VirusNotFound | VirusFound | FileNotExist | BlockedByPolicy
  [AVScanResultType] ScanAndClean([string]$path) {
    if (-not [IO.Path]::IsPathRooted($path)) {
      throw [ArgumentException]::new("Path is not rooted.", "path")
    }
    # IAttachmentExecute must run on an STA thread.
    # In PS 7+ (MTA default) we spin up a dedicated STA thread.
    if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -eq [System.Threading.ApartmentState]::STA) {
      return ($this._ScanAndCleanCore($path)).ResType
    } else {
      return $this._RunOnSTAThread($path)
    }
  }

  ## Pipeline-friendly overload that accepts a FileInfo object.
  [AVScanResultType] ScanAndClean([IO.FileInfo]$fileInfo) {
    return $this.ScanAndClean($fileInfo.FullName)
  }

  ## Convenience static factory: create a Scanner and scan in one call.
  static [AVScanResultType] Scan([string]$path) {
    return [AvScanner]::new().ScanAndClean($path)
  }

  ## Returns a human-readable description for an [AVScanResultType] value.
  static [string] Describe([AVScanResultType]$result) {
    $map = @{
      [AVScanResultType]::VirusNotFound   = "No virus was detected."
      [AVScanResultType]::VirusFound      = "A virus was detected. The file may have been cleaned or quarantined."
      [AVScanResultType]::FileNotExist    = "The specified file does not exist."
      [AVScanResultType]::BlockedByPolicy = "The file was blocked by security policy."
    }
    $desc = $map[[AVScanResultType]$result]
    if ($null -ne $desc) { return $desc }
    return "Unknown scan result: $result"
  }

  # -------------------------------------------------------------------------
  # Hidden / internal helpers
  # -------------------------------------------------------------------------

  ## Searches all loaded assemblies in the current AppDomain for a type by
  ## its full name. This is needed because Add-Type compiles into an anonymous
  ## dynamic assembly whose name cannot be used with [type]::GetType(string).
  ## We CANNOT use [AntiVirus.COMInterop.*] type literals in PS class bodies
  ## because the types don't exist yet at parse/compile time (using module).
  hidden static [type] _FindType([string]$fullName) {
    foreach ($asm in [AppDomain]::CurrentDomain.GetAssemblies()) {
      $t = $asm.GetType($fullName)
      if ($null -ne $t) { return $t }
    }
    throw [InvalidOperationException]::new(
      "Could not find type '$fullName' in any loaded assembly. " +
      "Ensure COMInterop.psm1 has been imported and Add-Type completed successfully."
    )
  }

  ## Core scanning logic – must be called from an STA thread.
  ## Delegates the actual COM work to AntiVirus.COMInterop.AttachmentScanner.ScanFile()
  ## We invoke it through reflection so that no [AntiVirus.COMInterop.*] type
  ## literals appear in this PS class body (they would fail at parse time).
  hidden [AVScanResult] _ScanAndCleanCore([string]$path) {
    # Invoke static ScanFile(Guid clientGuid, string path) → int (HRESULT)
    [int]$hresult = [AttachmentScannerCOM]::ScanFile($this.ClientGuid, $path)

    [AVScanResultType]$ResultType = switch ($hresult) {
      0          { "VirusNotFound"; break }  # S_OK
      -2146631666 { "BlockedByPolicy"; break }  # 0x800C000E: INET_E_SECURITY_PROBLEM
      -2147024894 { "FileNotExist"; break }  # 0x80070002: ERROR_FILE_NOT_FOUND or 0x80070057 in some cases
      -2147024809 { "FileNotExist"; break }  # 0x80070057: E_INVALIDARG (often returned when file missing for this API)
      -2147467259 { "VirusFound"; break }  # 0x80004005: E_FAIL
      default {
        throw [Runtime.InteropServices.COMException]::new(
          ("Unexpected HRESULT from IAttachmentExecute.Save(): 0x{0:X8} ($hresult)" -f $hresult),
          $hresult
        )
      }
    }

    # Unreachable – satisfies PowerShell's return-type requirement.
    return [AVScanResult]::new($ResultType)
  }

  ## Spins up a dedicated STA thread to run _ScanAndCleanCore(), then
  ## surfaces the result or re-throws any exception on the calling thread.
  hidden [AVScanResult] _RunOnSTAThread([string]$path) {
    $self = $this
    $capturedPath = $path
    $resultRef = [ref][AVScanResultType]::VirusNotFound
    $exceptionRef = [ref]$null

    $staThread = [System.Threading.Thread]::new(
      [ThreadStart] {
        try {
          $resultRef.Value = $self._ScanAndCleanCore($capturedPath)
        } catch {
          $exceptionRef.Value = $_.Exception
        }
      }
    )
    $staThread.SetApartmentState([ApartmentState]::STA)
    $staThread.Start()
    $staThread.Join()

    if ($null -ne $exceptionRef.Value) {
      throw [Exception]::new(
        "Unexpected exception on STA scanning thread: $($exceptionRef.Value.Message)",
        $exceptionRef.Value
      )
    }
    return $resultRef.Value.ResType
  }
  static [void] RunTestScans() {

    Write-Host "`n=== AntiVirus Scanner Tests ===" -ForegroundColor Cyan

    # Test 1: Basic construction
    $s = [AvScanner]::new()
    Write-Host "[PASS] Scanner instantiated. ClientGuid: $($s.ClientGuid)" -ForegroundColor Green

    # Test 2: Custom GUID constructor
    $customGuid = [Guid]::NewGuid()
    $s2 = [AvScanner]::new($customGuid)
    Write-Host "[PASS] Custom-GUID Scanner: $($s2.ClientGuid)" -ForegroundColor Green

    # Test 3: String GUID constructor
    $s3 = [AvScanner]::new("{C467440F-8ACB-449B-A7B1-05B7405C3753}")
    Write-Host "[PASS] String-GUID Scanner: $($s3.ClientGuid)" -ForegroundColor Green

    # Test 4: Describe static method
    foreach ($val in [Enum]::GetValues([AVScanResultType])) {
      $desc = [AvScanner]::Describe($val)
      Write-Host "[PASS] Describe($val): $desc" -ForegroundColor Green
    }

    # Test 5: FileNotExist path
    $fakePath = "C:\does_not_exist_12345.txt"
    Write-Host "`nScanning non-existent file: $fakePath" -ForegroundColor Yellow
    try {
      $result = [AvScanner]::Scan($fakePath)
      Write-Host "[RESULT] $result" -ForegroundColor Cyan
    } catch {
      Write-Host "[INFO] Scan threw: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Test 6: Rooted path check
    Write-Host "`nTesting non-rooted path guard..." -ForegroundColor Yellow
    try {
      $s.ScanAndClean("relative\path.txt")
      Write-Host "[FAIL] Should have thrown!" -ForegroundColor Red
    } catch [ArgumentException] {
      Write-Host "[PASS] Correctly rejected non-rooted path: $($_.Exception.Message)" -ForegroundColor Green
    }

    # Test 7: Scan a real safe file (notepad.exe)
    $notepad = "C:\Windows\System32\notepad.exe"
    if (Test-Path $notepad) {
      Write-Host "`nScanning: $notepad" -ForegroundColor Yellow
      $result = $s.ScanAndClean($notepad)
      Write-Host "[RESULT] $result  ->  $([AvScanner]::Describe($result))" -ForegroundColor Cyan
    }
    Write-Host "`n=== All tests complete ===" -ForegroundColor Cyan
  }
}
