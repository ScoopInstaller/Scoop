if (!$script:run) { $script:run = 0 }
if (!$script:failed) { $script:failed = 0 }

function filter_tests($arg) {
    if (!$arg) { return }
    $script:filter = $arg -join ' '
    Write-Host "filtering by '$filter'"
}
function test($desc, $assertions) {
    if ($filter -and $desc -notlike "*$filter*") { return }
    $script:test = $desc
    $script:run++
    try {
        $assertions.invoke()
    } catch {
        script:fail $_.exception.innerexception.message
    }
    $script:test = $null
}

function assert($x, $eq = '__undefined', $ne = '__undefined') {
    if ($args.length -gt 0) {
        fail "unexpected arguments: $args"
    }

    if ($eq -ne '__undefined') {
        if ($x -ne $eq) { fail "$(fmt $x) != $(fmt $eq)" }
    } elseif ($ne -ne '__undefined') {
        if ($x -eq $ne) { fail "$(fmt $x) == $(fmt $ne)" }
    } else {
        if (!$x) { fail "$x" }
    }
}

function test_results {
    $col = 'darkgreen'
    $res = 'all passed'
    if ($script:failed -gt 0) {
        $col = 'darkred'
        $res = "$script:failed failed"
    }

    Write-Host "ran $script:run tests, " -NoNewline
    Write-Host $res -f $col
}

function script:fail($msg) {
    $script:failed++
    $invoked = (Get-Variable -Scope 1 myinvocation).value

    $script = Split-Path $invoked.scriptname -Leaf
    $line = $invoked.scriptlinenumber

    if ($script:test) { $msg = "$script:test`r`n      -> $msg" }

    Write-Host "FAIL: $msg" -f darkred
    Write-Host "$script line $line`:"
    Write-Host (($invoked.positionmessage -split "`r`n")[1..2] -join "`r`n")
}

function script:fmt($var) {
    if ($null -eq $var) { return "`$null" }
    if ($var -is [string]) { return "'$var'" }
    return $var
}

# copies fixtures to a working directory
function setup_working($name) {
    $fixtures = "$PSScriptRoot/fixtures/$name"
    if (!(Test-Path $fixtures)) {
        Write-Host "couldn't find fixtures for $name at $fixtures" -f red
        exit 1
    }

    # reset working dir
    if ($PSVersionTable.Platform -eq 'Unix') {
        $working_dir = "/tmp/ScoopTestFixtures/$name"
    } else {
        $working_dir = "$env:TEMP/ScoopTestFixtures/$name"
    }

    if (Test-Path $working_dir) {
        Remove-Item -Recurse -Force $working_dir
    }

    # set up
    Copy-Item $fixtures -Destination $working_dir -Recurse

    return $working_dir
}
