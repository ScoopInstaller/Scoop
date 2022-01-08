[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [String]
    $repo_dir = (Get-Item $MyInvocation.PSScriptRoot).FullName
)

. "$psscriptroot\Scoop-TestLib.ps1"
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\unix.ps1"

$repo_files = @(Get-ChildItem $repo_dir -File -Recurse)

$project_file_exclusions = @(
    '[\\/]\.git[\\/]',
    '.sublime-workspace$',
    '.DS_Store$'
)

$bucketdir = $repo_dir
if (Test-Path("$repo_dir\..\bucket")) {
    $bucketdir = "$repo_dir\..\bucket"
} elseif (Test-Path("$repo_dir\bucket")) {
    $bucketdir = "$repo_dir\bucket"
}

. "$psscriptroot\Import-File-Tests.ps1"
. "$psscriptroot\Scoop-Manifest.Tests.ps1" -bucketdir $bucketdir
