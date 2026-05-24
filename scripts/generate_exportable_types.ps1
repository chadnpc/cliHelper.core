# return a string of types to export, comma separated
return (Get-ChildItem *.psm1 -Recurse -File | ForEach-Object {
    [IO.File]::ReadAllLines((Get-Item $_.FullName)).Where({
        $_.StartsWith("class") -or $_.StartsWith("enum ")
      }
    ).ForEach({
        $_.Replace("class ", '[').Replace("enum ", '[')
      }
    ).ForEach({
        ($_ -like "* : *") ? $_.split(" : ")[0] + ']' : $_.Replace(' {', ']')
      }
    )
  }
) -join ', '