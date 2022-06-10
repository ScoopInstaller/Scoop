. "$PSScriptRoot\Scoop-TestLib.ps1"
. "$PSScriptRoot\..\lib\core.ps1"
. "$PSScriptRoot\..\lib\depends.ps1"
. "$PSScriptRoot\..\lib\buckets.ps1"
. "$PSScriptRoot\..\lib\install.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"

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
            $working_dir = setup_working 'format/formated'
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
            Mock get_config { $false } -ParameterFilter { $name -eq 'MSIEXTRACT_USE_LESSMSI' }
            Mock get_config { $true } -ParameterFilter { $name -eq '7ZIPEXTRACT_USE_EXTERNAL' }
            Get-InstallationHelper -Manifest $manifest1 -Architecture '32bit' | Should -BeNullOrEmpty
            Get-InstallationHelper -Manifest $manifest2 -Architecture '32bit' | Should -BeNullOrEmpty
        }
        It 'Not return installed helpers' {
            Mock get_config { $true } -ParameterFilter { $name -eq 'MSIEXTRACT_USE_LESSMSI' }
            Mock get_config { $false } -ParameterFilter { $name -eq '7ZIPEXTRACT_USE_EXTERNAL' }
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
            Mock get_config { $true } -ParameterFilter { $name -eq 'MSIEXTRACT_USE_LESSMSI' }
            Mock Find-Manifest { $null, @{}, $null, $null } -ParameterFilter { $AppName -eq 'lessmsi' }
            Mock Find-Manifest { $null, @{ url = 'test.msi' }, $null, $null } -ParameterFilter { $AppName -eq '7zip' }
            Mock Find-Manifest { $null, @{}, $null, $null } -ParameterFilter { $AppName -eq 'innounp' }
        }

        It 'Resolve install dependencies' {
            Mock Find-Manifest { $null, @{ url = 'test.7z' }, $null, $null }
            Get-Dependency -AppName 'test' -Architecture '32bit' | Should -Be @('lessmsi', '7zip', 'test')
            Mock Find-Manifest { $null, @{ innosetup = $true }, $null, $null }
            Get-Dependency -AppName 'test' -Architecture '32bit' | Should -Be @('innounp', 'test')
        }
        It 'Resolve script dependencies' {
            Mock Find-Manifest { $null, @{ pre_install = 'Expand-7zipArchive ' }, $null, $null }
            Get-Dependency -AppName 'test' -Architecture '32bit' | Should -Be @('lessmsi', '7zip', 'test')
        }
        It 'Resolve runtime dependencies' {
            Mock Find-Manifest { $null, @{}, $null, $null } -ParameterFilter { $AppName -eq 'depends' }
            Mock Find-Manifest { $null, @{ depends = 'depends' }, $null, $null }
            Get-Dependency -AppName 'test' -Architecture '32bit' | Should -Be @('depends', 'test')
        }
        It 'Keep bucket name of app' {
            Mock Find-Manifest { $null, @{}, $null, $null } -ParameterFilter { $AppName -eq 'bucket/depends' }
            Mock Find-Manifest { $null, @{ depends = 'bucket/depends' }, $null, $null }
            Get-Dependency -AppName 'anotherbucket/test' -Architecture '32bit' | Should -Be @('bucket/depends', 'anotherbucket/test')
        }
    }
}
