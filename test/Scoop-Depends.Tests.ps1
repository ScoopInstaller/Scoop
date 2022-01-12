. "$psscriptroot\Scoop-TestLib.ps1"
. "$psscriptroot\..\lib\depends.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\manifest.ps1"

Describe 'Requirement function' -Tag 'Scoop' {
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
}

Describe 'InstallationHelper function' -Tag 'Scoop' {
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
