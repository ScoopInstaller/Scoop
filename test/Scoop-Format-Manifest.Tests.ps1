. "$psscriptroot\Scoop-TestLib.ps1"
. "$psscriptroot\..\lib\json.ps1"
. "$psscriptroot\..\lib\manifest.ps1"

Describe 'Pretty json formating' -Tag 'Scoop' {
    BeforeAll {
        $format = "$PSScriptRoot\fixtures\format"
        $manifests = Get-ChildItem "$format\formated" -File
    }

    Context 'Beatify manifest' {
        $manifests | ForEach-Object {
            It "$_" {
                $pretty_json = (parse_json "$format\unformated\$_") | ConvertToPrettyJson
                $correct = (Get-Content "$format\formated\$_") -join "`r`n"
                $correct.CompareTo($pretty_json) | Should Be 0
            }
        }
    }
}
