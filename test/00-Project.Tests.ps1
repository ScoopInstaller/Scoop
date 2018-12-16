$repo_dir = (Get-Item $MyInvocation.MyCommand.Path).Directory.Parent.FullName

$repo_files = @( Get-ChildItem $repo_dir -file -recurse -force )

$project_file_exclusions = @(
    $([regex]::Escape($repo_dir)+'(\\|/).git(\\|/).*$'),
    '.sublime-workspace$',
    '.DS_Store$',
    'supporting(\\|/)validator(\\|/)packages(\\|/)*',
    'supporting(\\|/)shimexe(\\|/)packages(\\|/)*'
)

describe 'Project code' {

    $files = @(
        $repo_files |
            where-object { $_.fullname -inotmatch $($project_file_exclusions -join '|') } |
            where-object { $_.fullname -imatch '.(ps1|psm1)$' }
    )

    $files_exist = ($files.Count -gt 0)

    it $('PowerShell code files exist ({0} found)' -f $files.Count) -skip:$(-not $files_exist) {
        if (-not ($files.Count -gt 0))
        {
            throw "No PowerShell code files were found"
        }
    }

    function Test-PowerShellSyntax {
        # ref: http://powershell.org/wp/forums/topic/how-to-check-syntax-of-scripts-automatically @@ https://archive.is/xtSv6
        # originally created by Alexander Petrovskiy & Dave Wyatt
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

    it 'PowerShell code files do not contain syntax errors' -skip:$(-not $files_exist) {
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

. "$psscriptroot\Import-File-Tests.ps1"
