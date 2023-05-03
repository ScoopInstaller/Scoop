# copies fixtures to a working directory
function setup_working($name) {
    $fixtures = "$PSScriptRoot/fixtures/$name"
    if (!(Test-Path $fixtures)) {
        Write-Host "couldn't find fixtures for $name at $fixtures" -f red
        exit 1
    }

    # reset working dir
    $working_dir = "$([IO.Path]::GetTempPath())ScoopTestFixtures/$name"

    if (Test-Path $working_dir) {
        Remove-Item -Recurse -Force $working_dir
    }

    # set up
    Copy-Item $fixtures -Destination $working_dir -Recurse

    return $working_dir
}
