# Usage: scoop checkup
# Summary: Check for potential problems
# Help: Performs a series of diagnostic tests to try to identify things that may
# cause problems with Scoop.

. "$PSScriptRoot\..\lib\diagnostic.ps1"

$issues = 0
$defenderIssues = 0


if (Test-IsAdmin -and $env:USERNAME -ne 'WDAGUtilityAccount') {
    $defenderIssues += !(Invoke-WindowsDefenderCheck $false)
    $defenderIssues += !(Invoke-WindowsDefenderCheck $true)
}

$issues += !(Invoke-MainBucketCheck)
$issues += !(Invoke-LongPathsCheck)
$issues += !(Invoke-WindowsDeveloperModeCheck)

if (!(Test-HelperInstalled -Helper 7zip)) {
    warn "'7-Zip' is not installed! It's required for unpacking most programs. Please Run 'scoop install 7zip' or 'scoop install 7zip-zstd'."
    $issues++
}

if (!(Test-HelperInstalled -Helper Innounp)) {
    warn "'Inno Setup Unpacker' is not installed! It's required for unpacking InnoSetup files. Please run 'scoop install innounp'."
    $issues++
}

if (!(Test-HelperInstalled -Helper Dark)) {
    warn "'dark' is not installed! It's required for unpacking installers created with the WiX Toolset. Please run 'scoop install dark' or 'scoop install wixtoolset'."
    $issues++
}

$globaldir = New-Object System.IO.DriveInfo($globaldir)
if ($globaldir.DriveFormat -ne 'NTFS') {
    error "Scoop requires an NTFS volume to work! Please point `$env:SCOOP_GLOBAL or 'global_path' variable in '~/.config/scoop/config.json' to another Drive."
    $issues++
}

$scoopdir = New-Object System.IO.DriveInfo($scoopdir)
if ($scoopdir.DriveFormat -ne 'NTFS') {
    error "Scoop requires an NTFS volume to work! Please point `$env:SCOOP or 'root_path' variable in '~/.config/scoop/config.json' to another Drive."
    $issues++
}

if ($issues) {
    warn "Found $issues potential $(pluralize $issues problem problems)."
} elseif ($defenderIssues) {
    info "Found $defenderIssues performance $(pluralize $defenderIssues problem problems)."
    warn "Security is more important than performance, in most cases."
} else {
    success "No problems identified!"
}

exit 0
