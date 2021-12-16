if([String]::IsNullOrEmpty($MyInvocation.PSScriptRoot)) {
    Write-Error 'This script should not be called directly! It has to be imported from a buckets test file!'
    exit 1
}

describe 'Style constraints for non-binary project files' {

    $files = @(
        # gather all files except '*.exe', '*.zip', or any .git repository files
        $repo_files |
            where-object { $_.fullname -inotmatch $($project_file_exclusions -join '|') } |
            where-object { $_.fullname -inotmatch '(.exe|.zip|.dll)$' } |
            where-object { $_.fullname -inotmatch '(unformated)' }
    )

    $files_exist = ($files.Count -gt 0)

    it $('non-binary project files exist ({0} found)' -f $files.Count) -skip:$(-not $files_exist) {
        if (-not ($files.Count -gt 0))
        {
            throw "No non-binary project were found"
        }
    }

    it 'files do not contain leading UTF-8 BOM' -skip:$(-not $files_exist) {
        # UTF-8 BOM == 0xEF 0xBB 0xBF
        # see http://www.powershellmagazine.com/2012/12/17/pscxtip-how-to-determine-the-byte-order-mark-of-a-text-file @@ https://archive.is/RgT42
        # ref: http://poshcode.org/2153 @@ https://archive.is/sGnnu
        $badFiles = @(
            foreach ($file in $files)
            {
                if((Get-Command Get-Content).parameters.ContainsKey('AsByteStream')) {
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

        if ($badFiles.Count -gt 0)
        {
            throw "The following files have utf-8 BOM: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }

    it 'registry files should be UTF-16LE encoded' -skip:$(-not $files_exist) {
        # Unicode files with BOM
        # UTF-7 == 0x2B 0x2F 0x76
        # UTF-8 == 0xEF 0xBB 0xBF
        # UTF-16LE == 0xFF 0xFE
        # UTF-16BE == 0xFE 0xFF
<<<<<<< HEAD
        # UTF-32LE == 0xFF 0xFE 0x00 0x00
        # UTF-32BE == 0x00 0x00 0xFE 0xFF
=======
        # UTF-32-LE == 0xFF 0xFE 0x00 0x00
        # UTF-32-BE == 0x00 0x00 0xFE 0xFF
>>>>>>> 125ac1e35088f6252d7bf2ebb8478e3398a5f734
        # see https://gist.github.com/SalviaSage/8eba542dc27eea3379a1f7dad3f729a0
        # see http://www.powershellmagazine.com/2012/12/17/pscxtip-how-to-determine-the-byte-order-mark-of-a-text-file @@ https://archive.is/RgT42
        # see https://en.wikipedia.org/w/index.php?title=Windows_Registry&action=view&section=19#.REG_files
        $badFiles = @(
            foreach ($file in $files)
            {
                if ([regex]::match($file.FullName, '(?<=\.)reg$').success)){
                    if((Get-Command Get-Content).parameters.ContainsKey('AsByteStream')) {
                        # PowerShell Core (6.0+) '-Encoding byte' is replaced by '-AsByteStream'
                        $byteContent = [byte[]](Get-Content $file.FullName -AsByteStream -ReadCount 4 -TotalCount 4)
                    } else {
                        $byteContent = [byte[]](Get-Content $file.FullName -Encoding byte -ReadCount 4 -TotalCount 4)
                    }
                    $content = [System.BitConverter]::ToString($byteContent)
                    # note that all the detection is done based on BOM
                    # all encodings which do not have BOM default
                    switch ($content) {
                        {$_ -match '^2B-2F-76'} { #endianless
                            Write-Error -Message "[Error]: Your registry is *UTF7* encoded please, correct it to *UTF-16LE-BOM*!`r`n"; break
                        }
                        {$_ -match '^EF-BB-BF'} { #endianless
                            Write-Warning -Message "[WARNING]: Your registry is *UTF8-BOM* encoded, please correct it to *UTF-16LE-BOM*!`r`n"; break
                        }
                        {$_ -match '^FF-FE'} { #little endian
                            Write-Verbose -Message "[INFO]: Your registry file correctly encoded to *UTF-16LE-BOM*!`r`n" -Verbose
                        }
                        {$_ -match '^FE-FF'} { #big endian
                            Write-Error -Message "[Error]: Your registry is *UTF16BE* encoded, please correct it to *UTF-16LE-BOM*!`r`n"; break
                        }
                        {$_ -match '^FF-FE-00-00'} { #little endian
                            Write-Error -Message "[Error]: Your registry is *UTF-32-LE* encoded, please correct it to *UTF-16LE-BOM*!`r`n"; break
                        }
                        {$_ -match '^FF-FE-00-00'} { #big endian
                            Write-Error -Message "[Error]: Your registry is *UTF-32-BE* encoded, please correct it to *UTF-16LE-BOM*!`r`n"; break
                        }
                        default { 
                            Write-Warning -Message "[WARNING]: *Unrecognized* registry encoding, probably missing BOM (byte order mark), please correct it to *UTF-16LE-BOM*`r`n"; break
                        }
                    }

                    if (([regex]::match($content, -match '^2B-2F-76')) -or # UTF-7
                        ([regex]::match($content, -match '^FE-FF')) -or # UTF-16BE
<<<<<<< HEAD
                        ([regex]::match($content, -match '^FF-FE-00-00')) -or # UTF-32LE
                        ([regex]::match($content, -match '^00-00-FE-FF')) ) { #UTF-32BE
=======
                        ([regex]::match($content, -match '^FF-FE-00-00')) -or # UTF-32-LE
                        ([regex]::match($content, -match '^00-00-FE-FF')) ) { #UTF-32-BE
>>>>>>> 125ac1e35088f6252d7bf2ebb8478e3398a5f734
                            $file.FullName
                    }
                }
        )

        if ($badFiles.Count -gt 0)
        {
            throw "The following registry files have incorrect encoding (fix it to *UTF-16LE-BOM*): `r`n`r`n$($badFiles -join "`r`n")"
        }
    }


    it 'files end with a newline' -skip:$(-not $files_exist) {
        $badFiles = @(
            foreach ($file in $files)
            {
                # Ignore previous TestResults.xml
                if ($file -match "TestResults.xml") {
                    continue
                }
                $string = [System.IO.File]::ReadAllText($file.FullName)
                if ($string.Length -gt 0 -and $string[-1] -ne "`n")
                {
                    $file.FullName
                }
            }
        )

        if ($badFiles.Count -gt 0)
        {
            throw "The following files do not end with a newline: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }

    it 'file newlines are CRLF' -skip:$(-not $files_exist) {
        $badFiles = @(
            foreach ($file in $files)
            {
                $content = Get-Content -raw $file.FullName
                if(!$content) {
                    throw "File contents are null: $($file.FullName)"
                }
                $lines = [regex]::split($content, '\r\n')
                $lineCount = $lines.Count

                for ($i = 0; $i -lt $lineCount; $i++)
                {
                    if ( [regex]::match($lines[$i], '\r|\n').success )
                    {
                        $file.FullName
                        break
                    }
                }
            }
        )

        if ($badFiles.Count -gt 0)
        {
            throw "The following files have non-CRLF line endings: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }

    it 'files have no lines containing trailing whitespace' -skip:$(-not $files_exist) {
        $badLines = @(
            foreach ($file in $files)
            {
                # Ignore previous TestResults.xml
                if ($file -match "TestResults.xml") {
                    continue
                }
                $lines = [System.IO.File]::ReadAllLines($file.FullName)
                $lineCount = $lines.Count

                for ($i = 0; $i -lt $lineCount; $i++)
                {
                    if ($lines[$i] -match '\s+$')
                    {
                        'File: {0}, Line: {1}' -f $file.FullName, ($i + 1)
                    }
                }
            }
        )

        if ($badLines.Count -gt 0)
        {
            throw "The following $($badLines.Count) lines contain trailing whitespace: `r`n`r`n$($badLines -join "`r`n")"
        }
    }

    it 'any leading whitespace consists only of spaces (excepting makefiles)' -skip:$(-not $files_exist) {
        $badLines = @(
            foreach ($file in $files)
            {
                if ($file.fullname -inotmatch '(^|.)makefile$')
                {
                    $lines = [System.IO.File]::ReadAllLines($file.FullName)
                    $lineCount = $lines.Count

                    for ($i = 0; $i -lt $lineCount; $i++)
                    {
                        if ($lines[$i] -notmatch '^[ ]*(\S|$)')
                        {
                            'File: {0}, Line: {1}' -f $file.FullName, ($i + 1)
                        }
                    }
                }
            }
        )

        if ($badLines.Count -gt 0)
        {
            throw "The following $($badLines.Count) lines contain TABs within leading whitespace: `r`n`r`n$($badLines -join "`r`n")"
        }
    }

}
