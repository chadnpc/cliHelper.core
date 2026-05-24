using namespace System

# ---------------------------------------------------------------------------
# COMInterop – Pure PowerShell COM wrappers for Windows IAttachmentExecute API
# ---------------------------------------------------------------------------

# Use Add-Type to define the IAttachmentExecute interface for reliable COM calls.
# We use [PreserveSig] for methods like Save() so we can manually handle HRESULTs.
$attachmentTypeDefinition = @'
using System;
using System.Runtime.InteropServices;

namespace AntiVirus.Interop {
    [ComImport]
    [Guid("73db1241-1e85-4581-8e4f-a81e1d0f8c57")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IAttachmentExecute {
        void SetClientGuid(ref Guid guid);
        void SetClientTitle([MarshalAs(UnmanagedType.LPWStr)] string title);
        void SetFileName([MarshalAs(UnmanagedType.LPWStr)] string fileName);
        void SetLocalPath([MarshalAs(UnmanagedType.LPWStr)] string localPath);
        void SetEditMode(bool editMode);
        void SetSource([MarshalAs(UnmanagedType.LPWStr)] string source);
        void SetReferrer([MarshalAs(UnmanagedType.LPWStr)] string referrer);
        void CheckPolicy();
        [PreserveSig]
        int Prompt(IntPtr hwnd, uint prompt, out uint action);
        [PreserveSig]
        int Save();
        [PreserveSig]
        int Execute(IntPtr hwnd, [MarshalAs(UnmanagedType.LPWStr)] string verb, out IntPtr process);
        [PreserveSig]
        int SaveWithProgress(IntPtr hwnd, [MarshalAs(UnmanagedType.LPWStr)] string verb, out IntPtr process);
        void ClearClientState();
    }

    public static class AttachmentExecuteHelper {
        public static int Scan(object comObject, Guid clientGuid, string path) {
            IAttachmentExecute atsvc = (IAttachmentExecute)comObject;
            atsvc.SetClientGuid(ref clientGuid);
            atsvc.SetFileName(path);
            atsvc.SetLocalPath(path);
            atsvc.SetSource("about:internet");
            return atsvc.Save();
        }

        public static void Clear(object comObject) {
            try {
                IAttachmentExecute atsvc = (IAttachmentExecute)comObject;
                atsvc.ClearClientState();
            } catch {}
        }
    }
}
'@

try {
  Add-Type -TypeDefinition $attachmentTypeDefinition -ErrorAction SilentlyContinue
} catch {
  # Type may already be defined in the session.
}

# Helper class that wraps the IAttachmentExecute COM API
class AttachmentScannerCOM {
  hidden static [Guid] $CLSID_AttachmentServices = [Guid]::new("4125dd96-e03a-4103-8f70-e0597d803b9c")

  # Create an instance of the COM AttachmentServices CoClass.
  static [object] CreateAttachmentExecute() {
    $comType = [Type]::GetTypeFromCLSID([AttachmentScannerCOM]::CLSID_AttachmentServices)
    if ($null -eq $comType) {
      throw [System.InvalidOperationException]::new(
        "IAttachmentExecute COM class not registered on this system. " +
        "This API is available on Windows 7+ with an antivirus product installed."
      )
    }
    return [System.Activator]::CreateInstance($comType)
  }

  ## Searches loaded assemblies for a type by name.
  hidden static [type] _FindType([string]$fullName) {
    foreach ($asm in [AppDomain]::CurrentDomain.GetAssemblies()) {
      $t = $asm.GetType($fullName)
      if ($null -ne $t) { return $t }
    }
    return $null
  }

  # Scan a file using the IAttachmentExecute COM API.
  # Returns the raw HRESULT as a signed int.
  static [int] ScanFile([Guid]$clientGuid, [string]$path) {
    $rawObj = [AttachmentScannerCOM]::CreateAttachmentExecute()

    # Use runtime type lookup to avoid parse-time errors in PowerShell classes.
    $helperType = [AttachmentScannerCOM]::_FindType("AntiVirus.Interop.AttachmentExecuteHelper")
    if ($null -eq $helperType) {
      throw [InvalidOperationException]::new("Could not find AntiVirus.Interop.AttachmentExecuteHelper. Ensure Add-Type succeeded.")
    }

    try {
      # Orchestrate the call via the C# helper for reliable IUnknown access.
      [int]$hresult = $helperType::Scan($rawObj, $clientGuid, $path)
      return $hresult
    } catch {
      throw [System.InvalidOperationException]::new(
        "Failed to perform AV scan via IAttachmentExecute: $($_.Exception.Message)",
        $_.Exception
      )
    } finally {
      try {
        $helperType::Clear($rawObj)
      } catch { $null }
      [System.Runtime.InteropServices.Marshal]::ReleaseComObject($rawObj) | Out-Null
    }
  }
}

# These classes are kept if needed for type reference, though the C# interface
# defined above is what handles the actual work.
class IAttachmentExecute {
  [string]$FileName
  [string]$Source
  [string]$ClientTitle
  [guid]$ClientGuid
  [string]$LocalPath
  [string]$Referrer
  [void] Save() {}
  [void] Execute($Process) {}
  [void] ClearClientState() {}
}