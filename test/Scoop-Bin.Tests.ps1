BeforeAll {
    $repo_root = (Resolve-Path "$PSScriptRoot\..").Path
    $shell_exe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
}

Describe 'bin/scoop.ps1' -Tag 'Scoop', 'Windows' {
    It 'keeps function aliases working when WhatIf is enabled' {
        $ast = [Management.Automation.Language.Parser]::ParseFile("$repo_root\bin\scoop.ps1", [ref]$null, [ref]$null)
        $alias_setup = $ast.EndBlock.Statements | Where-Object { $_.Extent.Text -match '^\$aliases =|^Get-ChildItem Function:' }
        $setup_script = [ScriptBlock]::Create(($alias_setup.Extent.Text -join "`n"))
        function ScoopAliasWhatIfTest { 'function-result' }
        Set-Alias -Name ScoopAliasWhatIfTest -Value Get-Date -Scope Script
        $old_whatif = $WhatIfPreference
        try {
            $WhatIfPreference = $true
            . $setup_script

            (Get-Alias ScoopAliasWhatIfTest).Definition | Should-Be 'Local:ScoopAliasWhatIfTest'
            ScoopAliasWhatIfTest | Should-Be 'function-result'
        } finally {
            $WhatIfPreference = $old_whatif
            Remove-Item Alias:ScoopAliasWhatIfTest -WhatIf:$false -ErrorAction SilentlyContinue
        }
    }

    It 'prints the formatted output of a command that returns objects' {
        $root = Join-Path $TestDrive 'scoop-root'
        $shim_dir = Join-Path $root 'shims'
        New-Item -ItemType Directory -Path $shim_dir -Force | Out-Null
        $target = Join-Path $root 'scoop-fake-target.ps1'
        [IO.File]::WriteAllText($target, "[PSCustomObject]@{ Marker = 'zzz-fake-output' }")
        [IO.File]::WriteAllText((Join-Path $shim_dir 'scoop-fake.ps1'), "`$path = '$target'")

        $old_scoop = $env:SCOOP
        $env:SCOOP = $root
        try {
            $output = & $shell_exe -NoProfile -ExecutionPolicy Bypass -File "$repo_root\bin\scoop.ps1" fake 2>&1 | Out-String
            $code = $LASTEXITCODE
        } finally {
            $env:SCOOP = $old_scoop
        }

        $code | Should-Be 0
        ($output -match 'zzz-fake-output') | Should-BeTrue
    }
}
