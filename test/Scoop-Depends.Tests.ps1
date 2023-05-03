BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\depends.ps1"
    . "$PSScriptRoot\..\lib\buckets.ps1"
    . "$PSScriptRoot\..\lib\install.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
}

Describe 'Package Dependencies' -Tag 'Scoop' {
    Context 'Requirement function' {
        It 'Test 7zip requirement' {
            Test-7zipRequirement -Uri 'test.xz' | Should -BeTrue
            Test-7zipRequirement -Uri 'test.bin' | Should -BeFalse
            Test-7zipRequirement -Uri @('test.xz', 'test.bin') | Should -BeTrue
        }
        It 'Test Zstd requirement' {
            Test-ZstdRequirement -Uri 'test.zst' | Should -BeTrue
            Test-ZstdRequirement -Uri 'test.bin' | Should -BeFalse
            Test-ZstdRequirement -Uri @('test.zst', 'test.bin') | Should -BeTrue
        }
        It 'Test lessmsi requirement' {
            Mock get_config { $true }
            Test-LessmsiRequirement -Uri 'test.msi' | Should -BeTrue
            Test-LessmsiRequirement -Uri 'test.bin' | Should -BeFalse
            Test-LessmsiRequirement -Uri @('test.msi', 'test.bin') | Should -BeTrue
        }
        It 'Allow $Uri be $null' {
            Test-7zipRequirement -Uri $null | Should -BeFalse
            Test-ZstdRequirement -Uri $null | Should -BeFalse
            Test-LessmsiRequirement -Uri $null | Should -BeFalse
        }
    }

    Context 'InstallationHelper function' {
        BeforeAll {
            $working_dir = setup_working 'format/formatted'
            $manifest1 = parse_json (Join-Path $working_dir '3-array-with-single-and-multi.json')
            $manifest2 = parse_json (Join-Path $working_dir '4-script-block.json')
            Mock Test-HelperInstalled { $false }
        }
        It 'Get helpers from URL' {
            Mock get_config { $true }
            Get-InstallationHelper -Manifest $manifest1 -Architecture '32bit' | Should -Be @('lessmsi')
        }
        It 'Get helpers from script' {
            Mock get_config { $false }
            Get-InstallationHelper -Manifest $manifest2 -Architecture '32bit' | Should -Be @('7zip')
        }
        It 'Helpers reflect config changes' {
            Mock get_config { $false } -ParameterFilter { $name -eq 'USE_LESSMSI' }
            Mock get_config { $true } -ParameterFilter { $name -eq 'USE_EXTERNAL_7ZIP' }
            Get-InstallationHelper -Manifest $manifest1 -Architecture '32bit' | Should -BeNullOrEmpty
            Get-InstallationHelper -Manifest $manifest2 -Architecture '32bit' | Should -BeNullOrEmpty
        }
        It 'Not return installed helpers' {
            Mock get_config { $true } -ParameterFilter { $name -eq 'USE_LESSMSI' }
            Mock get_config { $false } -ParameterFilter { $name -eq 'USE_EXTERNAL_7ZIP' }
            Mock Test-HelperInstalled { $true }-ParameterFilter { $Helper -eq '7zip' }
            Mock Test-HelperInstalled { $false }-ParameterFilter { $Helper -eq 'Lessmsi' }
            Get-InstallationHelper -Manifest $manifest1 -Architecture '32bit' | Should -Be @('lessmsi')
            Get-InstallationHelper -Manifest $manifest2 -Architecture '32bit' | Should -BeNullOrEmpty
            Mock Test-HelperInstalled { $false }-ParameterFilter { $Helper -eq '7zip' }
            Mock Test-HelperInstalled { $true }-ParameterFilter { $Helper -eq 'Lessmsi' }
            Get-InstallationHelper -Manifest $manifest1 -Architecture '32bit' | Should -BeNullOrEmpty
            Get-InstallationHelper -Manifest $manifest2 -Architecture '32bit' | Should -Be @('7zip')
        }
    }

    Context 'Dependencies resolution' {
        BeforeAll {
            Mock Test-HelperInstalled { $false }
            Mock get_config { $true } -ParameterFilter { $name -eq 'USE_LESSMSI' }
            Mock Get-Manifest { 'lessmsi', @{}, $null, $null } -ParameterFilter { $app -eq 'lessmsi' }
            Mock Get-Manifest { '7zip', @{ url = 'test.msi' }, $null, $null } -ParameterFilter { $app -eq '7zip' }
            Mock Get-Manifest { 'innounp', @{}, $null, $null } -ParameterFilter { $app -eq 'innounp' }
        }

        It 'Resolve install dependencies' {
            Mock Get-Manifest { 'test', @{ url = 'test.7z' }, $null, $null }
            Get-Dependency -AppName 'test' -Architecture '32bit' | Should -Be @('lessmsi', '7zip', 'test')
            Mock Get-Manifest { 'test', @{ innosetup = $true }, $null, $null }
            Get-Dependency -AppName 'test' -Architecture '32bit' | Should -Be @('innounp', 'test')
        }
        It 'Resolve script dependencies' {
            Mock Get-Manifest { 'test', @{ pre_install = 'Expand-7zipArchive ' }, $null, $null }
            Get-Dependency -AppName 'test' -Architecture '32bit' | Should -Be @('lessmsi', '7zip', 'test')
        }
        It 'Resolve runtime dependencies' {
            Mock Get-Manifest { 'depends', @{}, $null, $null } -ParameterFilter { $app -eq 'depends' }
            Mock Get-Manifest { 'test', @{ depends = 'depends' }, $null, $null }
            Get-Dependency -AppName 'test' -Architecture '32bit' | Should -Be @('depends', 'test')
        }
        It 'Keep bucket name of app' {
            Mock Get-Manifest { 'depends', @{}, 'anotherbucket', $null } -ParameterFilter { $app -eq 'anotherbucket/depends' }
            Mock Get-Manifest { 'test', @{ depends = 'anotherbucket/depends' }, 'bucket', $null }
            Get-Dependency -AppName 'bucket/test' -Architecture '32bit' | Should -Be @('anotherbucket/depends', 'bucket/test')
        }
    }
}
