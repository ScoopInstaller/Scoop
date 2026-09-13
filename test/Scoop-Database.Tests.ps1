Describe 'database version selection' -Tag 'Scoop' {
    BeforeAll {
        . "$PSScriptRoot\Scoop-TestLib.ps1"
        . "$PSScriptRoot\..\lib\core.ps1"
        . "$PSScriptRoot\..\lib\versions.ps1"
        . "$PSScriptRoot\..\lib\database.ps1"
    }

    It 'chooses the semantically latest row within one result set' {
        $rows = @(
            [pscustomobject]@{ version = '1.0.7' }
            [pscustomobject]@{ version = '1.0.31' }
        )

        (Get-LatestScoopDBRow -Rows $rows).version | Should -Be '1.0.31'
    }

    It 'returns null when no rows are provided' {
        Get-LatestScoopDBRow -Rows @() | Should -Be $null
    }

    It 'returns the latest semantic version per name and bucket' {
        $result = New-Object System.Data.DataTable
        [void]$result.Columns.Add('name', [string])
        [void]$result.Columns.Add('version', [string])
        [void]$result.Columns.Add('bucket', [string])
        [void]$result.Columns.Add('binary', [string])
        [void]$result.Rows.Add('copilot-cli', '1.0.7', 'main', 'copilot')
        [void]$result.Rows.Add('copilot-cli', '1.0.31', 'main', 'copilot')
        [void]$result.Rows.Add('zotero', '7.0.9', 'extras', 'zotero')
        [void]$result.Rows.Add('zotero', '7.0.20', 'extras', 'zotero')
        [void]$result.Rows.Add('zotero', '7.0.9', 'he0119', 'zotero')
        [void]$result.Rows.Add('zotero', '7.0.20', 'he0119', 'zotero')

        $latest = @(Select-LatestScoopDBRow -Table $result -GroupBy @('name', 'bucket'))

        $latest.Count | Should -Be 3
        (@($latest | Where-Object { $_.name -eq 'copilot-cli' -and $_.bucket -eq 'main' })[0]).version | Should -Be '1.0.31'
        (@($latest | Where-Object { $_.name -eq 'zotero' -and $_.bucket -eq 'extras' })[0]).version | Should -Be '7.0.20'
        (@($latest | Where-Object { $_.name -eq 'zotero' -and $_.bucket -eq 'he0119' })[0]).version | Should -Be '7.0.20'
    }

    It 'returns the latest semantic version when no grouping is requested' {
        $result = New-Object System.Data.DataTable
        [void]$result.Columns.Add('name', [string])
        [void]$result.Columns.Add('version', [string])
        [void]$result.Columns.Add('bucket', [string])
        [void]$result.Columns.Add('binary', [string])
        [void]$result.Rows.Add('zotero', '7.0.9', 'extras', 'zotero')
        [void]$result.Rows.Add('zotero', '7.0.20', 'extras', 'zotero')

        $latest = @(Select-LatestScoopDBRow -Table $result)

        $latest.Count | Should -Be 1
        $latest[0].version | Should -Be '7.0.20'
    }
}
