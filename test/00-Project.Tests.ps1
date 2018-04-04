$repo_dir = (Get-Item $MyInvocation.MyCommand.Path).directory.parent.FullName

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

describe 'Style constraints for non-binary project files' {

    $files = @(
        # gather all files except '*.exe', '*.zip', or any .git repository files
        $repo_files |
            where-object { $_.fullname -inotmatch $($project_file_exclusions -join '|') } |
            where-object { $_.fullname -inotmatch '(.exe|.zip|.dll)$' }
    )

    $files_exist = ($files.Count -gt 0)

    it $('non-binary project files exist ({0} found)' -f $files.Count) -skip:$(-not $files_exist) {
        if (-not ($files.Count -gt 0))
        {
            throw "No non-binary project were found"
        }
    }

    it 'files do not contain leading utf-8 BOM' -skip:$(-not $files_exist) {
        # utf-8 BOM == 0xEF 0xBB 0xBF
        # see http://www.powershellmagazine.com/2012/12/17/pscxtip-how-to-determine-the-byte-order-mark-of-a-text-file @@ https://archive.is/RgT42
        # ref: http://poshcode.org/2153 @@ https://archive.is/sGnnu

        # As of PowerShell 6.0, `Get-Content` on non-Windows platform does not support `-Encoding Byte`
        # The following try-catch is to work around that by using .NET framework
        $read_bytes_type = 'default'
        function read_bytes ([string]$FileName, [int]$Size) {
            if ($read_bytes_type -eq 'default') {
                return Get-Content "$FileName" -Encoding Byte -TotalCount $Size
            }
            else {
                $buffer = [byte[]](0, 0, 0)
                $fstream = (New-Object -TypeName System.IO.FileStream -ArgumentList ("$FileName", [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read))
                $fstream.Read($buffer, 0, $Size) > $null
                return $buffer
            }
        }
        try {
            # Following would throw exception if `-Encoding Byte` is not supported
            $null = read_bytes -FileName $MyInvocation.PSCommandPath -Size 3
        }
        catch {
            $read_bytes_type = 'dotnet'
        }

        $badFiles = @(
            foreach ($file in $files)
            {
                # Ignore previous TestResults.xml
                if ($file -match "TestResults.xml") {
                    continue
                }
                $buffer = read_bytes -FileName "$($file.FullName)" -Size 3
                $content = ([char[]]$buffer -join '')
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
