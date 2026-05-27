using assembly .\Lib\Capstone\capstone.dll
using assembly .\Lib\De4dot\dnlib.dll

class Capstone {
  static [object] CSDisassemble([object]$Architecture, [object]$Mode, [byte[]]$Code, [long]$Offset, [int]$Count, [string]$Syntax, [bool]$DetailOn, [bool]$Version) {
    if ($Version) {
      $Disassembly = New-Object Capstone.Capstone(([type]'Capstone.Architecture')::X86, ([type]'Capstone.Mode')::Mode16)
      return $Disassembly.Version
    }

    if ($null -eq $Architecture -or $null -eq $Mode) {
      $Architecture = ([type]'Capstone.Architecture')::X86
      $Mode = ([type]'Capstone.Mode')::Mode16
    }

    $Disassembly = New-Object Capstone.Capstone($Architecture, $Mode)

    if ($Disassembly.Version -ne ([type]'Capstone.Capstone')::BindingVersion) {
      Write-Error "capstone.dll version ($(([type]'Capstone.Capstone')::BindingVersion.ToString())) should be the same as libcapstone.dll version. Otherwise, undefined behavior is likely."
    }

    if ($Syntax) {
      $SyntaxMode = $null
      switch ($Syntax) {
        'Intel' { $SyntaxMode = ([type]'Capstone.OptionValue')::SyntaxIntel }
        'ATT' { $SyntaxMode = ([type]'Capstone.OptionValue')::SyntaxATT }
      }

      if ($null -ne $SyntaxMode) {
        $Disassembly.SetSyntax($SyntaxMode)
      }
    }

    if ($DetailOn) {
      $Disassembly.SetDetail($True)
    }

    return $Disassembly.Disassemble($Code, $Offset, $Count)
  }

  static [object] ILDisassemble([object]$MethodInfo, [string]$AssemblyPath, [long]$MetadataToken, [object]$MethodDef) {
    $Method = $null
    if ($null -ne $AssemblyPath) {
      $FullPath = Resolve-Path $AssemblyPath
      $Module = ([type]'dnlib.DotNet.ModuleDefMD')::Load($FullPath.Path)
      $Method = $Module.ResolveMethod(($MetadataToken -band 0xFFFFFF))
    } elseif ($null -ne $MethodInfo) {
      $Module = ([type]'dnlib.DotNet.ModuleDefMD')::Load($MethodInfo.Module)
      $Method = $Module.ResolveMethod(($MethodInfo.MetadataToken -band 0xFFFFFF))
    } elseif ($null -ne $MethodDef) {
      $Method = $MethodDef
    }

    if ($null -ne $Method -and $Method.HasBody) {
      $Result = @{
        Name          = $Method.Name.String
        MetadataToken = "0x$($Method.MDToken.Raw.ToString('X8'))"
        Signature     = $Method.ToString()
        Instructions  = $Method.MethodBody.Instructions
      }

      $Disasm = New-Object PSObject -Property $Result
      $Disasm.PSObject.TypeNames.Insert(0, 'IL_METAINFO')

      return $Disasm
    } else {
      if ($null -ne $Method) {
        Write-Warning "Method is not implemented. Name: $($Method.Name.String), MetadataToken: 0x$($Method.MDToken.Raw.ToString('X8'))"
      }
      return $null
    }
  }
}


