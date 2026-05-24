using namespace System
using namespace System.Collections.Generic
using namespace System.Runtime.InteropServices

using module .\Exceptions.psm1
using module .\Utilities.psm1

class DllUtils {
  static [object] ConvertToString([System.String] $Path) {
    $FileStream = New-Object -TypeName IO.FileStream -ArgumentList (Resolve-Path $Path), 'Open', 'Read'
    $Encoding = [Text.Encoding]::GetEncoding(28591)
    $StreamReader = New-Object IO.StreamReader($FileStream, $Encoding)
    $BinaryText = $StreamReader.ReadToEnd()
    $StreamReader.Close()
    $FileStream.Close()
    return $BinaryText
  }

  static [double] GetEntropy([System.Byte[]] $ByteArray, [System.IO.FileInfo] $FilePath) {
    if ($FilePath) {
      $ByteArray = [IO.File]::ReadAllBytes($FilePath.FullName)
    }
    if (!$ByteArray) { return 0.0 }

    $FrequencyTable = @{}
    foreach ($Byte in $ByteArray) {
      $FrequencyTable[$Byte] = [int]$FrequencyTable[$Byte] + 1
    }

    $Entropy = 0.0
    foreach ($Byte in 0..255) {
      $ByteProbability = ([Double] $FrequencyTable[[Byte]$Byte]) / $ByteArray.Length
      if ($ByteProbability -gt 0) {
        $Entropy += - $ByteProbability * [Math]::Log($ByteProbability, 2)
      }
    }
    return $Entropy
  }

  static [object[]] GetStrings([string[]] $Paths, [System.String] $Encoding = 'Default', [System.UInt32] $MinimumLength = 3) {
    $Results = @()
    foreach ($Path in $Paths) {
      if ($Encoding -eq 'Unicode' -or $Encoding -eq 'Default') {
        $UnicodeFileContents = Get-Content -Encoding Unicode $Path -Raw
        $UnicodeRegex = [Regex]::new("[\u0020-\u007E]{$MinimumLength,}")
        foreach ($match in $UnicodeRegex.Matches($UnicodeFileContents)) { $Results += $match.Value }
      }
      if ($Encoding -eq 'Ascii' -or $Encoding -eq 'Default') {
        $AsciiFileContents = Get-Content -Encoding Ascii $Path -Raw
        $AsciiRegex = [Regex]::new("[\x20-\x7E]{$MinimumLength,}")
        foreach ($match in $AsciiRegex.Matches($AsciiFileContents)) { $Results += $match.Value }
      }
    }
    return $Results
  }

  # Helper for creating delegate types
  static [Type] GetDelegateType([Type[]]$Parameters, [Type]$ReturnType) {
    $Domain = [AppDomain]::CurrentDomain
    $DynAssembly = [System.Reflection.AssemblyName]::new('ReflectedDelegate')
    $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run)
    $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('InMemoryModule')
    $TypeBuilder = $ModuleBuilder.DefineType('MyDelegateType', 'Class, Public, Sealed, AnsiClass, AutoClass', [System.MulticastDelegate])

    $ConstructorBuilder = $TypeBuilder.DefineConstructor('RTSpecialName, HideBySig, Public', [System.Reflection.CallingConventions]::Standard, $Parameters)
    $ConstructorBuilder.SetImplementationFlags('Runtime, Managed')

    $MethodBuilder = $TypeBuilder.DefineMethod('Invoke', 'Public, HideBySig, NewSlot, Virtual', $ReturnType, $Parameters)
    $MethodBuilder.SetImplementationFlags('Runtime, Managed')

    return $TypeBuilder.CreateType()
  }

  static [Type] $Win32NativeMethods = $null

  static [void] InitNativeMethods() {
    if ($null -ne [DllUtils]::Win32NativeMethods) { return }
    $type = ('DllUtils.NativeMethods' -as [type])
    if ($type) {
      [DllUtils]::Win32NativeMethods = $type
      return
    }
    $Signature = @'
[DllImport("kernel32.dll", SetLastError=true)]
public static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
public static extern IntPtr LoadLibrary(string lpFileName);
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Ansi)]
public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
[DllImport("iphlpapi.dll", ExactSpelling = true)]
public static extern int SendARP(uint destIp, uint srcIp, byte[] macAddr, ref int macLen);
'@
    [DllUtils]::Win32NativeMethods = Add-Type -MemberDefinition $Signature -Name "NativeMethods" -Namespace "DllUtils" -PassThru
  }

  # PInvoke for SendARP
  static [int] SendARP([uint32]$destIp, [uint32]$srcIp, [byte[]]$macAddr, [int]$macLen) {
    [DllUtils]::InitNativeMethods()
    $refMacLen = $macLen
    return [DllUtils]::Win32NativeMethods::SendARP($destIp, $srcIp, $macAddr, [ref]$refMacLen)
  }

  # PInvoke for VirtualAlloc
  static [IntPtr] VirtualAlloc([IntPtr]$lpAddress, [uint32]$dwSize, [uint32]$flAllocationType, [uint32]$flProtect) {
    [DllUtils]::InitNativeMethods()
    return [DllUtils]::Win32NativeMethods::VirtualAlloc($lpAddress, $dwSize, $flAllocationType, $flProtect)
  }

  static [IntPtr] LoadLibrary([string]$lpFileName) {
    [DllUtils]::InitNativeMethods()
    return [DllUtils]::Win32NativeMethods::LoadLibrary($lpFileName)
  }

  static [IntPtr] GetProcAddress([IntPtr]$hModule, [string]$procName) {
    [DllUtils]::InitNativeMethods()
    return [DllUtils]::Win32NativeMethods::GetProcAddress($hModule, $procName)
  }

  static [Delegate] NewFunctionDelegate([Type[]]$Parameters, [Type]$ReturnType, [Byte[]]$FunctionBytes, [IntPtr]$FunctionAddress, [CallingConvention]$CallingConvention) {
    if ($FunctionBytes) {
      $PBytes = [DllUtils]::VirtualAlloc([IntPtr]::Zero, $FunctionBytes.Length, 0x3000, 0x40)
      [Marshal]::Copy($FunctionBytes, 0, $PBytes, $FunctionBytes.Length)
      $FunctionAddress = $PBytes
    }

    $DelegateType = [DllUtils]::GetDelegateType($Parameters, $ReturnType)
    return [Marshal]::GetDelegateForFunctionPointer($FunctionAddress, $DelegateType)
  }

  # dnlib integration
  static [object] GetAssemblyImplementedMethods([string]$AssemblyPath) {
    # Assuming dnlib is loaded
    $Module = [dnlib.DotNet.ModuleDefMD]::Load($AssemblyPath)
    $Methods = New-Object 'System.Collections.Generic.List[dnlib.DotNet.MethodDef]'
    foreach ($Type in $Module.GetTypes()) {
      foreach ($Method in $Type.Methods) {
        if ($Method.HasBody) { $Methods.Add($Method) }
      }
    }
    return $Methods
  }
}