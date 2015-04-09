. "lib/core.ps1"

function Run-Test($test) {
    exec { powershell "./test/$test" }
}

task . {
    abort 'There is no default build task'
}

task Test {
    "Running tests..."
}, 
MoveDir, 
HashTable, 
Packages,
Opts,
Versions,
Vimrc

task MoveDir {
    run-test movedir
}

task HashTable {
    run-test ht
}

task Packages {
    run-test packages
}

task Opts {
    run-test opts
}

task Versions {
    run-test versions
}

task Vimrc {
    run-test vimrc
}