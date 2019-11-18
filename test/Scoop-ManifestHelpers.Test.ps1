. "$PSScriptRoot\..\lib\ManifestHelpers.ps1"

describe 'Manifest Helpers' -Tag 'Scoop' {
    context '.NET Framework' {
        it 'Release key convert' {
            Convert-DotNetFrameworkVersion '4.5' | Should -Be '378389'
            Convert-DotNetFrameworkVersion '4.7.1' | Should -Be '461308'
            Convert-DotNetFrameworkVersion '4.7.2' | Should -Be '461808'
            Convert-DotNetFrameworkVersion '4.8' | Should -Be '528040'
            Convert-DotNetFrameworkVersion '4.8.03752' | Should -Be '528040'
        }

        # TODO: Convert
    }
}
