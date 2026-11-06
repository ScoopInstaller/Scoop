BeforeAll {
    $repo_root = (Resolve-Path "$PSScriptRoot\..").Path
    $core = [Management.Automation.Language.Parser]::ParseFile("$repo_root\lib\core.ps1", [ref]$null, [ref]$null)
    $size_function = $core.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'filesize' }, $false)
    . ([ScriptBlock]::Create($size_function.Extent.Text))
    $cache = [Management.Automation.Language.Parser]::ParseFile("$repo_root\libexec\scoop-cache.ps1", [ref]$null, [ref]$null)
    foreach ($definition in $cache.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $false)) {
        . ([ScriptBlock]::Create($definition.Extent.Text))
    }
    function pluralize($number, $singular, $plural) { if ($number -eq 1) { $singular } else { $plural } }
}

Describe 'cache show' -Tag 'Scoop' {
    BeforeEach {
        $cachedir = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $cachedir | Out-Null
    }

    It 'shows readable sizes while preserving application names and versions' {
        [IO.File]::WriteAllBytes((Join-Path $cachedir 'small#1.0#url'), [byte[]]::new(512))
        [IO.File]::WriteAllBytes((Join-Path $cachedir 'large#2.0#url'), [byte[]]::new(2048))

        $rows = @(cacheshow '*')

        $rows.Count | Should-Be 2
        ($rows | Where-Object Name -eq 'small').Version | Should-Be '1.0'
        ($rows | Where-Object Name -eq 'small').Size | Should-Be '512 B'
        ($rows | Where-Object Name -eq 'large').Size | Should-Be (filesize 2048)
        (($rows | Format-Table | Out-String) -match 'Size') | Should-BeTrue
    }

    It 'filters the requested app and handles empty files' {
        [IO.File]::WriteAllBytes((Join-Path $cachedir 'empty#3.0#url'), [byte[]]::new(0))
        [IO.File]::WriteAllBytes((Join-Path $cachedir 'other#1.0#url'), [byte[]]::new(32))

        $rows = @(cacheshow 'empty')

        $rows.Count | Should-Be 1
        $rows[0].Name | Should-Be 'empty'
        $rows[0].Size | Should-Be '0 B'
    }

    It 'returns no rows for an empty cache' {
        @(cacheshow '*').Count | Should-Be 0
    }
}
