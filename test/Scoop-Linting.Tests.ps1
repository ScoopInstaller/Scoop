$repo_dir = (Get-Item $MyInvocation.MyCommand.Path).directory.parent.FullName
$scoop_modules = Get-ChildItem $repo_dir -Filter "*.ps1" -Recurse
$linting_settings = Get-Item -Path "$repo_dir\PSScriptAnalyzerSettings.psd1"

Describe "Linting all modules" {
    foreach($module in $scoop_modules) {
        Context "Linting $module" {
              It "Passes PSScriptAnalyzer" {
                  (Invoke-ScriptAnalyzer $module.FullName -Settings $linting_settings.FullName).count | Should Be 0
              }
        }
    }
}
