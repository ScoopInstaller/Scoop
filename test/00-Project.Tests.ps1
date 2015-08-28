$repo_dir = (Get-Item $MyInvocation.MyCommand.Path).directory.parent.FullName

describe 'Project code' {

    $files = @(
        Get-ChildItem $repo_dir -file -recurse -force | ? { $_.fullname -match '.(ps1|psm1)$' }
    )

    function Test-PowerShellSyntax {
        #ref: http://powershell.org/wp/forums/topic/how-to-check-syntax-of-scripts-automatically @@ https://archive.is/xtSv6
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
            [string[]]
            $Path
        )

        process {
            foreach ($scriptPath in $Path) {
                $contents = Get-Content -Path $scriptPath

                if ($null -eq $contents) {
                    continue
                }

                $errors = $null
                $null = [System.Management.Automation.PSParser]::Tokenize($contents, [ref]$errors)

                New-Object psobject -Property @{
                    Path = $scriptPath
                    SyntaxErrorsFound = ($errors.Count -gt 0)
                }
            }
        }
    }

    it 'PowerShell files do not contain syntax errors' {
        $badFiles = @(
            foreach ($file in $files)
            {
                if ( (Test-PowerShellSyntax $file.FullName).SyntaxErrorsFound )
                {
                    $file.FullName
                }
            }
        )

        if ($badFiles.Count -gt 0)
        {
            throw "The following files have syntax errors: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }

}
