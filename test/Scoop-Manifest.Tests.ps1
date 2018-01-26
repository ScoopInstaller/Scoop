."$psscriptroot\Scoop-TestLib.ps1"
."$psscriptroot\..\lib\core.ps1"
."$psscriptroot\..\lib\manifest.ps1"

Describe "manifest-validation" {
  BeforeAll {
    $working_dir = setup_working "manifest"
    $schema = "$psscriptroot/../schema.json"
    Add-Type -Path "$psscriptroot\..\supporting\validator\Newtonsoft.Json.dll"
    Add-Type -Path "$psscriptroot\..\supporting\validator\Newtonsoft.Json.Schema.dll"
    Add-Type -Path "$psscriptroot\..\supporting\validator\Scoop.Validator.dll"
  }

  It "Scoop.Validator is available" {
    ([System.Management.Automation.PSTypeName]'Scoop.Validator').Type | Should be 'Scoop.Validator'
  }

  Context "parse_json function" {
    It "fails with invalid json" {
      { parse_json "$working_dir\broken_wget.json" } | Should throw
    }
  }

  Context "schema validation" {
    It "fails with broken schema" {
      $validator = New-Object Scoop.Validator ("$working_dir/broken_schema.json",$true)
      $validator.Validate("$working_dir/wget.json") | Should be $false
      $validator.Errors.count | Should be 1
      $validator.Errors | Select-Object -First 1 | Should match "broken_schema.*(line 6).*(position 4)"
    }
    It "fails with broken manifest" {
      $validator = New-Object Scoop.Validator ($schema,$true)
      $validator.Validate("$working_dir/broken_wget.json") | Should be $false
      $validator.Errors.count | Should be 1
      $validator.Errors | Select-Object -First 1 | Should match "broken_wget.*(line 5).*(position 4)"
    }
    It "fails with invalid manifest" {
      $validator = New-Object Scoop.Validator ($schema,$true)
      $validator.Validate("$working_dir/invalid_wget.json") | Should be $false
      $validator.Errors.count | Should be 16
      $validator.Errors | Select-Object -First 1 | Should match "invalid_wget.*randomproperty.*properties\.$"
      $validator.Errors | Select-Object -Last 1 | Should match "invalid_wget.*version\.$"
    }
  }

  Context "manifest validates against the schema" {
    BeforeAll {
      $bucketdir = "$psscriptroot\..\bucket\"
      $manifest_files = Get-ChildItem $bucketdir *.json
      $validator = New-Object Scoop.Validator ($schema,$true)
    }

    $global:quota_exceeded = $false

    $manifest_files | ForEach-Object {
      It "$_" {
        $file = $_ # exception handling may overwrite $_

        if (!($global:quota_exceeded)) {
          try {
            $validator.Validate($file.FullName)

            if ($validator.Errors.count -gt 0) {
              Write-Host -f yellow $validator.ErrorsAsString
            }
            $validator.Errors.count | Should be 0
          } catch {
            if ($_.exception.message -like '*The free-quota limit of 1000 schema validations per hour has been reached.*') {
              $global:quota_exceeded = $true
              Write-Host -f darkyellow 'Schema validation limit exceeded. Will skip further validations.'
            } else {
              throw
            }
          }
        }

        $manifest = parse_json $file.FullName
        $url = arch_specific "url" $manifest "32bit"
        $url64 = arch_specific "url" $manifest "64bit"
        if (!$url) {
          $url = $url64
        }
        $url | Should not benullorempty
      }
    }
  }
}
