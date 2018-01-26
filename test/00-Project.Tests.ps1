$repo_dir = (Get-Item $MyInvocation.mycommand.path).Directory.Parent.FullName

$repo_files = @( Get-ChildItem $repo_dir -File -Recurse -Force)

$project_file_exclusions = @(
  $([regex]::Escape($repo_dir) + '(\\|/).git(\\|/).*$'),
  '.sublime-workspace$',
  '.DS_Store$',
  'supporting(\\|/)validator(\\|/)packages(\\|/)*'
)

Describe 'Project code' {

  $files = @(
    $repo_files |
    Where-Object { $_.FullName -inotmatch $($project_file_exclusions -join '|') } |
    Where-Object { $_.FullName -imatch '.(ps1|psm1)$' }
  )

  $files_exist = ($files.count -gt 0)

  It $('PowerShell code files exist ({0} found)' -f $files.count) -skip:$(-not $files_exist) {
    if (-not ($files.count -gt 0))
    {
      throw "No PowerShell code files were found"
    }
  }

  function Test-PowerShellSyntax {
    # ref: http://powershell.org/wp/forums/topic/how-to-check-syntax-of-scripts-automatically @@ https://archive.is/xtSv6
    # originally created by Alexander Petrovskiy & Dave Wyatt
    [CmdletBinding()]
    param(
      [Parameter(Mandatory = $true,ValueFromPipeline = $true)]
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
        $null = [System.Management.Automation.PSParser]::Tokenize($contents,[ref]$errors)

        New-Object psobject -Property @{
          path = $scriptPath
          SyntaxErrorsFound = ($errors.count -gt 0)
        }
      }
    }
  }

  It 'PowerShell code files do not contain syntax errors' -skip:$(-not $files_exist) {
    $badFiles = @(
      foreach ($file in $files)
      {
        if ((Test-PowerShellSyntax $file.FullName).SyntaxErrorsFound)
        {
          $file.FullName
        }
      }
    )

    if ($badFiles.count -gt 0)
    {
      throw "The following files have syntax errors: `r`n`r`n$($badFiles -join "`r`n")"
    }
  }

}

Describe 'Style constraints for non-binary project files' {

  $files = @(
    # gather all files except '*.exe', '*.zip', or any .git repository files
    $repo_files |
    Where-Object { $_.FullName -inotmatch $($project_file_exclusions -join '|') } |
    Where-Object { $_.FullName -inotmatch '(.exe|.zip|.dll)$' }
  )

  $files_exist = ($files.count -gt 0)

  It $('non-binary project files exist ({0} found)' -f $files.count) -skip:$(-not $files_exist) {
    if (-not ($files.count -gt 0))
    {
      throw "No non-binary project were found"
    }
  }

  It 'files do not contain leading utf-8 BOM' -skip:$(-not $files_exist) {
    # utf-8 BOM == 0xEF 0xBB 0xBF
    # see http://www.powershellmagazine.com/2012/12/17/pscxtip-how-to-determine-the-byte-order-mark-of-a-text-file @@ https://archive.is/RgT42
    # ref: http://poshcode.org/2153 @@ https://archive.is/sGnnu
    $badFiles = @(
      foreach ($file in $files)
      {
        $content = ([char[]](Get-Content $file.FullName -Encoding byte -TotalCount 3) -join '')
        if ([regex]::match($content,'(?ms)^\xEF\xBB\xBF').Success)
        {
          $file.FullName
        }
      }
    )

    if ($badFiles.count -gt 0)
    {
      throw "The following files have utf-8 BOM: `r`n`r`n$($badFiles -join "`r`n")"
    }
  }

  It 'files end with a newline' -skip:$(-not $files_exist) {
    $badFiles = @(
      foreach ($file in $files)
      {
        $string = [System.IO.File]::ReadAllText($file.FullName)
        if ($string.length -gt 0 -and $string[-1] -ne "`n")
        {
          $file.FullName
        }
      }
    )

    if ($badFiles.count -gt 0)
    {
      throw "The following files do not end with a newline: `r`n`r`n$($badFiles -join "`r`n")"
    }
  }

  It 'file newlines are CRLF' -skip:$(-not $files_exist) {
    $badFiles = @(
      foreach ($file in $files)
      {
        $content = Get-Content -Raw $file.FullName
        if (!$content) {
          throw "File contents are null: $($file.FullName)"
        }
        $lines = [regex]::Split($content,'\r\n')
        $lineCount = $lines.count

        for ($i = 0; $i -lt $lineCount; $i++)
        {
          if ([regex]::match($lines[$i],'\r|\n').Success)
          {
            $file.FullName
            break
          }
        }
      }
    )

    if ($badFiles.count -gt 0)
    {
      throw "The following files have non-CRLF line endings: `r`n`r`n$($badFiles -join "`r`n")"
    }
  }

  It 'files have no lines containing trailing whitespace' -skip:$(-not $files_exist) {
    $badLines = @(
      foreach ($file in $files)
      {
        $lines = [System.IO.File]::ReadAllLines($file.FullName)
        $lineCount = $lines.count

        for ($i = 0; $i -lt $lineCount; $i++)
        {
          if ($lines[$i] -match '\s+$')
          {
            'File: {0}, Line: {1}' -f $file.FullName,($i + 1)
          }
        }
      }
    )

    if ($badLines.count -gt 0)
    {
      throw "The following $($badLines.Count) lines contain trailing whitespace: `r`n`r`n$($badLines -join "`r`n")"
    }
  }

  It 'any leading whitespace consists only of spaces (excepting makefiles)' -skip:$(-not $files_exist) {
    $badLines = @(
      foreach ($file in $files)
      {
        if ($file.FullName -inotmatch '(^|.)makefile$')
        {
          $lines = [System.IO.File]::ReadAllLines($file.FullName)
          $lineCount = $lines.count

          for ($i = 0; $i -lt $lineCount; $i++)
          {
            if ($lines[$i] -notmatch '^[ ]*(\S|$)')
            {
              'File: {0}, Line: {1}' -f $file.FullName,($i + 1)
            }
          }
        }
      }
    )

    if ($badLines.count -gt 0)
    {
      throw "The following $($badLines.Count) lines contain TABs within leading whitespace: `r`n`r`n$($badLines -join "`r`n")"
    }
  }

}
