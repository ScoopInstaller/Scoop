if([String]::IsNullOrEmpty($MyInvocation.PSScriptRoot)) {
    Write-Error 'This script should not be called directly! It has to be imported from a buckets test file!'
    exit 1
}

. "$psscriptroot\Scoop-TestLib.ps1"
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\unix.ps1"

$repo_dir = (Get-Item $MyInvocation.PSScriptRoot).FullName

$repo_files = @(Get-ChildItem $repo_dir -file -recurse)

$project_file_exclusions = @(
    $([regex]::Escape($repo_dir)+'(\\|/).git(\\|/).*$'),
    '.sublime-workspace$',
    '.DS_Store$',
    'supporting(\\|/)validator(\\|/)packages(\\|/)*'
)

$bucketdir = $repo_dir
if(Test-Path("$repo_dir\bucket")) {
    $bucketdir = "$repo_dir\bucket"
}

. "$psscriptroot\Import-File-Tests.ps1"
. "$psscriptroot\Scoop-Manifest.Tests.ps1" -bucketdir $bucketdir
