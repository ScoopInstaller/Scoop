$repo_dir = (Get-Item $MyInvocation.MyCommand.Path).directory.parent.FullName

describe 'Project style constraints' {

    $files = @(
        # gather all files except '*.exe', '*.zip', or any .git repository files
        Get-ChildItem $repo_dir -file -recurse -force | ? { $_.fullname -notmatch '(.git(|\\.*)|.exe|.zip)$' }
    )

    it 'files do not contain leading utf-8 BOM' {
        # utf-8 BOM == 0xEF 0xBB 0xBF
        # NOTE: utf-16LE BOM == 0xFF 0xFE; utf-16LE BOM == 0xFF 0xFE
        # see http://www.powershellmagazine.com/2012/12/17/pscxtip-how-to-determine-the-byte-order-mark-of-a-text-file @@ https://archive.is/RgT42
        # ref: http://poshcode.org/2153 @@ https://archive.is/sGnnu
        # ref: http://www.johndcook.com/blog/powershell_perl_regex @@ https://archive.is/gHa60
        $badFiles = @(
            foreach ($file in $files)
            {
                $content = ([char[]](Get-Content $file.FullName -encoding byte -totalcount 3) -join '')
                if ([regex]::match($content, '(?ms)^\xEF\xBB\xBF').success)
                {
                    $file.FullName
                }
            }
        )

        if ($badFiles.Count -gt 0)
        {
            throw "The following files have utf-8 BOM: `r`n`r`n$($badFiles -join "`r`n")"
        }
    }

    it 'files all have line endings which are CRLF' {
        # ref: http://www.johndcook.com/blog/powershell_perl_regex @@ https://archive.is/gHa60
        $badFiles = @(
            foreach ($file in $files)
            {
                $content = Get-Content -raw $file.FullName
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

    it 'files all end with a newline' {
        $badFiles = @(
            foreach ($file in $files)
            {
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

    it 'files have leading whitespace consisting only of spaces' {
        $badLines = @(
            foreach ($file in $files)
            {
                if ($file.fullname -notmatch 'makefile$')
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

    it 'files have no lines containing trailing whitespace' {
        $badLines = @(
            foreach ($file in $files)
            {
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

}
