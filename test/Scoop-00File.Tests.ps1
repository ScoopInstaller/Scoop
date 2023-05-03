param(
    [String] $TestPath = "$PSScriptRoot\.."
)

BeforeDiscovery {
    $project_file_exclusions = @(
        '[\\/]\.git[\\/]',
        '\.sublime-workspace$',
        '\.DS_Store$',
        'supporting(\\|/)validator(\\|/)packages(\\|/)*',
        'supporting(\\|/)shimexe(\\|/)packages(\\|/)*'
    )
    $repo_files = (Get-ChildItem $TestPath -File -Recurse).FullName |
        Where-Object { $_ -inotmatch $($project_file_exclusions -join '|') }
}

Describe 'Code Syntax' -ForEach @(, $repo_files) -Tag 'File' {
    BeforeAll {
        $files = @(
            $_ | Where-Object { $_ -imatch '.(ps1|psm1)$' }
        )
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
                        Path              = $scriptPath
                        SyntaxErrorsFound = ($errors.Count -gt 0)
                    }
                }
            }
        }

    }

    It 'PowerShell code files do not contain syntax errors' {
        $badFiles = @(
            foreach ($file in $files) {
                if ( (Test-PowerShellSyntax $file).SyntaxErrorsFound ) {
                    $file
                }
            }
        )

        if ($badFiles.Count -gt 0) {
            throw "The following files have syntax errors: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }

}

Describe 'Style constraints for non-binary project files' -ForEach @(, $repo_files) -Tag 'File' {
    BeforeAll {
        $files = @(
            # gather all files except '*.exe', '*.zip', or any .git repository files
            $_ |
                Where-Object { $_ -inotmatch '(.exe|.zip|.dll)$' } |
                Where-Object { $_ -inotmatch '(unformatted)' }
        )
    }

    It 'files do not contain leading UTF-8 BOM' {
        # UTF-8 BOM == 0xEF 0xBB 0xBF
        # see http://www.powershellmagazine.com/2012/12/17/pscxtip-how-to-determine-the-byte-order-mark-of-a-text-file @@ https://archive.is/RgT42
        # ref: http://poshcode.org/2153 @@ https://archive.is/sGnnu
        $badFiles = @(
            foreach ($file in $files) {
                if ((Get-Command Get-Content).parameters.ContainsKey('AsByteStream')) {
                    # PowerShell Core (6.0+) '-Encoding byte' is replaced by '-AsByteStream'
                    $content = ([char[]](Get-Content $file -AsByteStream -TotalCount 3) -join '')
                } else {
                    $content = ([char[]](Get-Content $file -Encoding byte -TotalCount 3) -join '')
                }
                if ([regex]::match($content, '(?ms)^\xEF\xBB\xBF').success) {
                    $file
                }
            }
        )

        if ($badFiles.Count -gt 0) {
            throw "The following files have utf-8 BOM: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }

    It 'files end with a newline' {
        $badFiles = @(
            foreach ($file in $files) {
                # Ignore previous TestResults.xml
                if ($file -match 'TestResults.xml') {
                    continue
                }
                $string = [System.IO.File]::ReadAllText($file)
                if ($string.Length -gt 0 -and $string[-1] -ne "`n") {
                    $file
                }
            }
        )

        if ($badFiles.Count -gt 0) {
            throw "The following files do not end with a newline: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }

    It 'file newlines are CRLF' {
        $badFiles = @(
            foreach ($file in $files) {
                $content = [System.IO.File]::ReadAllText($file)
                if (!$content) {
                    throw "File contents are null: $($file)"
                }
                $lines = [regex]::split($content, '\r\n')
                $lineCount = $lines.Count

                for ($i = 0; $i -lt $lineCount; $i++) {
                    if ( [regex]::match($lines[$i], '\r|\n').success ) {
                        $file
                        break
                    }
                }
            }
        )

        if ($badFiles.Count -gt 0) {
            throw "The following files have non-CRLF line endings: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }

    It 'files have no lines containing trailing whitespace' {
        $badLines = @(
            foreach ($file in $files) {
                # Ignore previous TestResults.xml
                if ($file -match 'TestResults.xml') {
                    continue
                }
                $lines = [System.IO.File]::ReadAllLines($file)
                $lineCount = $lines.Count

                for ($i = 0; $i -lt $lineCount; $i++) {
                    if ($lines[$i] -match '\s+$') {
                        'File: {0}, Line: {1}' -f $file, ($i + 1)
                    }
                }
            }
        )

        if ($badLines.Count -gt 0) {
            throw "The following $($badLines.Count) lines contain trailing whitespace: `r`n`r`n$($badLines -join "`r`n")"
        }
    }

    It 'any leading whitespace consists only of spaces (excepting makefiles)' {
        $badLines = @(
            foreach ($file in $files) {
                if ($file -inotmatch '(^|.)makefile$') {
                    $lines = [System.IO.File]::ReadAllLines($file)
                    $lineCount = $lines.Count

                    for ($i = 0; $i -lt $lineCount; $i++) {
                        if ($lines[$i] -notmatch '^[ ]*(\S|$)') {
                            'File: {0}, Line: {1}' -f $file, ($i + 1)
                        }
                    }
                }
            }
        )

        if ($badLines.Count -gt 0) {
            throw "The following $($badLines.Count) lines contain TABs within leading whitespace: `r`n`r`n$($badLines -join "`r`n")"
        }
    }

}
