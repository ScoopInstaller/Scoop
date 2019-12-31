#region Persists
function Test-Persistence {
    <#
    .SYNOPSIS
        Persistence check helper for files.
    .DESCRIPTION
        This will save some lines to not always write `if (-not (Test-Path "$persist_dir\$file")) { New-item "$dir\$file" | Out-Null }` inside manifests.
    .PARAMETER File
        File to be checked.
        Do not prefix with $dir. All files are already checked against $dir.
    .PARAMETER Content
        If file does not exists it will be created with this value. Value should be array of strings or string.
    .PARAMETER Execution
        Custom scriptblock to run when file is not persisted.
        https://github.com/lukesampson/scoop-extras/blob/a84b257fd9636d02295b48c3fd32826487ca9bd3/bucket/ditto.json#L25-L33
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [String[]] $File,
        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [Object[]] $Content,
        [ScriptBlock] $Execution
    )

    process {
        for ($ind = 0; $ind -lt $File.Count; ++$ind) {
            $currentFile = $File[$ind]

            if (-not (Join-Path $persist_dir $currentFile | Test-Path -PathType Leaf)) {
                if ($Execution) {
                    & $Execution
                } else {
                    # Handle edge case when there is only one file and mulitple contents caused by
                    # If `Test-Persistence alfa.txt @('new', 'beta')` is used,
                    # Powershell will bind Content as simple array with 2 values instead of Array with nested array with 2 values.
                    if (($File.Count -eq 1) -and ($Content.Count -gt 1)) {
                        $cont = $Content
                    } elseif ($ind -lt $Content.Count) {
                        $cont = $Content[$ind]
                    } else {
                        $cont = $null
                    }
                    $path = Join-Path $dir $currentFile

                    New-Item -Path $path -ItemType File -Force | Out-Null
                    if ($cont) { Set-Content -LiteralPath $path -Value $cont -Encoding Ascii }
                }
            }
        }
    }
}
#endregion Persists

function Remove-AppDirItem {
    <#
    .SYNOPSIS
        Remove given item from applications directory.
        Wildcards are supported.
    .PARAMETER Item
        Specify item for removing from $dir.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [String[]]
        $Item
    )

    process { foreach ($it in $Item) { Get-ChildItem $dir $it | Remove-Item -Force -Recurse } }
}

function Edit-File {
    <#
    .SYNOPSIS
        Find and replace text in given file.
    .PARAMETER File
        Specify file, which will be loaded.
        File could be passed as full path (used for changing files outside $dir) or just relative path to $dir.
    .PARAMETER Find
        Specify the string to be replaced.
    .PARAMETER Replace
        Specify the string for replacing all occurrences.
        Empty string is default => Found string will be removed.
    .PARAMETER Regex
        Specify if regular expression should be used instead of simple match.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String] $File,
        [Parameter(Mandatory = $true)]
        [String[]] $Find,
        [String[]] $Replace,
        [Switch] $Regex
    )

    begin {
        # Use file from $dir
        if (Join-Path $dir $File | Test-Path -PathType Leaf) { $File = Join-Path $dir $File }
        if (-not (Test-Path $File)) {
            error "File $File does not exist."
            return
        }
    }

    process {
        $content = Get-Content $File
        for ($i = 0; $i -lt $Find.Count; ++$i) {
            $toFind = $Find[$i]
            if (-not $Replace -or ($null -eq $Replace[$i])) {
                $toReplace = ''
            } else {
                $toReplace = $Replace[$i]
            }

            if ($Regex) {
                $content = $content -replace $toFind, $toReplace
            } else {
                $content = $content.Replace($toFind, $toReplace)
            }
        }

        Set-Content -LiteralPath $File -Value $content -Encoding Ascii -Force
    }
}

function New-JavaShortcutWrapper {
    <#
    .SYNOPSIS
        Create new shim-like batch file wrapper to spawn jar files within start menu (using shortcut).
    .PARAMETER FileName
        Jar executable filename without .jar extension.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([Parameter(Mandatory = $true, ValueFromPipeline = $true)] [String[]] $FileName)

    process {
        foreach ($f in $FileName) {
            Set-Content -LiteralPath (Join-Path $dir "$f.bat") -Value "@start javaw.exe -jar `"%~dp0$f.jar`" %*" -Encoding Ascii -Force
        }
    }
}
