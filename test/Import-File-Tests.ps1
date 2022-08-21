if ([String]::IsNullOrEmpty($MyInvocation.PSScriptRoot)) {
    Write-Error 'This script should not be called directly! It has to be imported from a buckets test file!'
    exit 1
}

Describe 'Style constraints for non-binary project files' {

    $files = @(
        # gather all files except '*.exe', '*.zip', or any .git repository files
        $repo_files |
            Where-Object { $_.fullname -inotmatch $($project_file_exclusions -join '|') } |
            Where-Object { $_.fullname -inotmatch '(.exe|.zip|.dll)$' } |
            Where-Object { $_.fullname -inotmatch '(unformatted)' }
    )

    $files_exist = ($files.Count -gt 0)

    It $('non-binary project files exist ({0} found)' -f $files.Count) -Skip:$(-not $files_exist) {
        if (-not ($files.Count -gt 0)) {
            throw 'No non-binary project were found'
        }
    }

    It 'files do not contain leading UTF-8 BOM' -Skip:$(-not $files_exist) {
        # UTF-8 BOM == 0xEF 0xBB 0xBF
        # see http://www.powershellmagazine.com/2012/12/17/pscxtip-how-to-determine-the-byte-order-mark-of-a-text-file @@ https://archive.is/RgT42
        # ref: http://poshcode.org/2153 @@ https://archive.is/sGnnu
        $badFiles = @(
            foreach ($file in $files) {
                if ((Get-Command Get-Content).parameters.ContainsKey('AsByteStream')) {
                    # PowerShell Core (6.0+) '-Encoding byte' is replaced by '-AsByteStream'
                    $content = ([char[]](Get-Content $file.FullName -AsByteStream -TotalCount 3) -join '')
                } else {
                    $content = ([char[]](Get-Content $file.FullName -Encoding byte -TotalCount 3) -join '')
                }
                if ([regex]::match($content, '(?ms)^\xEF\xBB\xBF').success) {
                    $file.FullName
                }
            }
        )

        if ($badFiles.Count -gt 0) {
            throw "The following files have utf-8 BOM: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }

    It 'files end with a newline' -Skip:$(-not $files_exist) {
        $badFiles = @(
            foreach ($file in $files) {
                # Ignore previous TestResults.xml
                if ($file -match 'TestResults.xml') {
                    continue
                }
                $string = [System.IO.File]::ReadAllText($file.FullName)
                if ($string.Length -gt 0 -and $string[-1] -ne "`n") {
                    $file.FullName
                }
            }
        )

        if ($badFiles.Count -gt 0) {
            throw "The following files do not end with a newline: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }

    It 'file newlines are CRLF' -Skip:$(-not $files_exist) {
        $badFiles = @(
            foreach ($file in $files) {
                $content = [System.IO.File]::ReadAllText($file.FullName)
                if (!$content) {
                    throw "File contents are null: $($file.FullName)"
                }
                $lines = [regex]::split($content, '\r\n')
                $lineCount = $lines.Count

                for ($i = 0; $i -lt $lineCount; $i++) {
                    if ( [regex]::match($lines[$i], '\r|\n').success ) {
                        $file.FullName
                        break
                    }
                }
            }
        )

        if ($badFiles.Count -gt 0) {
            throw "The following files have non-CRLF line endings: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }

    It 'files have no lines containing trailing whitespace' -Skip:$(-not $files_exist) {
        $badLines = @(
            foreach ($file in $files) {
                # Ignore previous TestResults.xml
                if ($file -match 'TestResults.xml') {
                    continue
                }
                $lines = [System.IO.File]::ReadAllLines($file.FullName)
                $lineCount = $lines.Count

                for ($i = 0; $i -lt $lineCount; $i++) {
                    if ($lines[$i] -match '\s+$') {
                        'File: {0}, Line: {1}' -f $file.FullName, ($i + 1)
                    }
                }
            }
        )

        if ($badLines.Count -gt 0) {
            throw "The following $($badLines.Count) lines contain trailing whitespace: `r`n`r`n$($badLines -join "`r`n")"
        }
    }

    It 'any leading whitespace consists only of spaces (excepting makefiles)' -Skip:$(-not $files_exist) {
        $badLines = @(
            foreach ($file in $files) {
                if ($file.fullname -inotmatch '(^|.)makefile$') {
                    $lines = [System.IO.File]::ReadAllLines($file.FullName)
                    $lineCount = $lines.Count

                    for ($i = 0; $i -lt $lineCount; $i++) {
                        if ($lines[$i] -notmatch '^[ ]*(\S|$)') {
                            'File: {0}, Line: {1}' -f $file.FullName, ($i + 1)
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
