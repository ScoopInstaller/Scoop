. "$PSScriptRoot\Scoop-TestLib.ps1"
. "$PSScriptRoot\..\lib\json.ps1"
. "$PSScriptRoot\..\lib\manifest.ps1"

Describe 'Pretty json formating' -Tag 'Scoop' {
    BeforeAll {
        $format = "$PSScriptRoot\fixtures\format"
        $manifests = Get-ChildItem "$format\formated" -File -Filter '*.json'
    }

    Context 'Beautify manifest' {
        $manifests | ForEach-Object {
            if ($PSVersionTable.PSVersion.Major -gt 5) { $_ = $_.Name } # Fix for pwsh

            It "$_" {
                $pretty_json = (parse_json "$format\unformated\$_") | ConvertToPrettyJson
                $correct = (Get-Content "$format\formated\$_") -join "`r`n"
                $correct.CompareTo($pretty_json) | Should -Be 0
            }
        }
    }
}
