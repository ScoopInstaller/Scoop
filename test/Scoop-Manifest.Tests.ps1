. "$psscriptroot\Scoop-TestLib.ps1"
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"

describe "manifest-validation" {
    beforeall {
        $working_dir = setup_working "manifest"
        $schema_json = gc "$psscriptroot\..\schema.json" -raw -Encoding UTF8
        Add-Type -Path "$psscriptroot\..\..\Newtonsoft.Json\lib\net45\Newtonsoft.Json.dll"
        Add-Type -Path "$psscriptroot\..\..\Newtonsoft.Json.Schema\lib\net45\Newtonsoft.Json.Schema.dll"
        [System.Collections.Generic.IList[System.String]]$validationErrors = new-object System.Collections.Generic.List[System.String]
    }

    context "Newtonsoft.Json" {
        it "Newtonsoft.Json.Linq.JToken is available" {
            ([System.Management.Automation.PSTypeName]'Newtonsoft.Json.Linq.JToken').Type | should be 'Newtonsoft.Json.Linq.JToken'
        }
        it "Newtonsoft.Json.Schema.JSchema is available" {
            ([System.Management.Automation.PSTypeName]'Newtonsoft.Json.Schema.JSchema').Type | should be 'Newtonsoft.Json.Schema.JSchema'
        }
        it "Newtonsoft.Json.Schema.SchemaExtensions is available" {
            ([System.Management.Automation.PSTypeName]'Newtonsoft.Json.Schema.SchemaExtensions').Type | should be 'Newtonsoft.Json.Schema.SchemaExtensions'
        }
    }

    context "parse_json function" {
        it "fails with invalid json" {
            { parse_json "$working_dir\broken_wget.json" } | should throw
        }
    }

    context "schema validation" {
        it "fails with broken schema" {
            $json = gc "$working_dir\broken_schema.json" -raw -Encoding UTF8
            { [Newtonsoft.Json.Schema.JSchema]::Parse($json) } | should throw
        }
        it "fails with broken manifest" {
            $json = gc "$working_dir\broken_wget.json" -raw -Encoding UTF8
            { [Newtonsoft.Json.Linq.JToken]::Parse($json) } | should throw
        }
        it "fails with invalid manifest" {
            $json = gc "$working_dir\invalid_wget.json" -raw -Encoding UTF8
            $manifest = [Newtonsoft.Json.Linq.JToken]::Parse($json)
            $schema = [Newtonsoft.Json.Schema.JSchema]::Parse($schema_json)
            [Newtonsoft.Json.Schema.SchemaExtensions]::IsValid($manifest, $schema, [ref]$validationErrors)
            $validationErrors.Count | should be 4
        }
    }

    context "manifest validates against the schema" {
        beforeall {
            $bucketdir = "$psscriptroot\..\bucket\"
            $manifest_files = gci $bucketdir *.json
            $schema = [Newtonsoft.Json.Schema.JSchema]::Parse($schema_json)
        }
        beforeeach {
        }
        $manifest_files | % {
            it "$_" {
                {
                    $json = gc $_.fullname -raw -Encoding UTF8
                    $manifest = [Newtonsoft.Json.Linq.JToken]::Parse($json)
                    [Newtonsoft.Json.Schema.SchemaExtensions]::IsValid($manifest, $schema, [ref]$validationErrors)
                } | should not throw
                $validationErrors.Count | should be 0

                $manifest = parse_json $_.fullname
                $url = arch_specific "url" $manifest "32bit"
                $url64 = arch_specific "url" $manifest "64bit"
                if(!$url) {
                    $url = $url64
                }
                $url | should not benullorempty
            }
        }
        aftereach {
            if ($validationErrors.Count -gt 0) {
                write-host -f yellow "    [*] $_ " -nonewline
                write-host -f yellow $([string]::join("`n    [*] $_ ", $validationErrors))
            }
        }
    }
}
