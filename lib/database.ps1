function Get-SQLite {
    # Install SQLite
    try {
        $sqlitePkgPath = "$env:TEMP\sqlite.nupkg"
        $sqliteTempPath = "$env:TEMP\sqlite"
        $sqlitePath = "$PSScriptRoot\..\supporting\sqlite"
        Invoke-WebRequest -Uri 'https://globalcdn.nuget.org/packages/stub.system.data.sqlite.core.netframework.1.0.116.nupkg' -OutFile $sqlitePkgPath
        Expand-Archive -Path $sqlitePkgPath -DestinationPath $sqliteTempPath -Force
        New-Item -Path $sqlitePath -ItemType Directory | Out-Null
        Move-Item -Path "$sqliteTempPath\build\net45\*" -Destination $sqlitePath -Exclude '*.targets' -Force
        Move-Item -Path "$sqliteTempPath\lib\net45\*" -Destination $sqlitePath -Force
        Remove-Item -Path $sqlitePkgPath, $sqliteTempPath -Recurse -Force
        return $true
    } catch {
        return $false
    }
}

function Open-ScoopDB {
    # Load System.Data.SQLite
    try {
        [Void][System.Data.SQLite.SQLiteConnection]
    } catch {
        if ( -not (Add-Type -Path "$PSScriptRoot\..\supporting\sqlite\System.Data.SQLite.dll" -PassThru -ErrorAction stop) ) {
            throw "Scoop's Database cache requires the ADO.NET driver:`n`thttp://system.data.sqlite.org/index.html/doc/trunk/www/downloads.wiki"
        }
    }
    $dbPath = Join-Path $scoopdir 'scoop.db'
    $db = New-Object -TypeName System.Data.SQLite.SQLiteConnection
    $db.ConnectionString = "Data Source=$dbPath"
    $db.ParseViaFramework = $true # Allow UNC path
    $db.Open()
    $db
}

function New-ScoopDB ([switch]$PassThru) {
    $db = Open-ScoopDB
    $appCommand = $db.CreateCommand()
    $appCommand.CommandText = "CREATE TABLE IF NOT EXISTS 'app' (
        name NTEXT NOT NULL,
        bucket VARCHAR(20) NOT NULL,
        manifest JSON NOT NULL,
        updated_at DATETIME NOT NULL,
        updated_by NTEXT NOT NULL,
        version TEXT NOT NULL,
        description NTEXT NOT NULL,
        homepage TEXT NOT NULL,
        license TEXT NOT NULL,
        binaries TEXT,
        shortcuts NTEXT,
        environment NTEXT,
        path NTEXT,
        dependencies NTEXT,
        suggests NTEXT,
        notes NTEXT
        version_local TEXT,
        version_global TEXT,
        hold_local BOOLEAN NOT NULL DEFAULT 0,
        hold_global BOOLEAN NOT NULL DEFAULT 0,
        generated_local BOOLEAN NOT NULL DEFAULT 0,
        generated_global BOOLEAN NOT NULL DEFAULT 0,
    )"
    $appCommand.ExecuteNonQuery() | Out-Null
    $appCommand.Dispose()
    $shimCommand.CommandText = "CREATE TABLE IF NOT EXISTS 'shim' (
        name TEXT NOT NULL,
        path NTEXT NOT NULL,
        source NTEXT NOT NULL,
        type DATETIME NOT NULL,
        alternatives TEXT,
        global BOOLEAN NOT NULL DEFAULT 0,
        hidden BOOLEAN NOT NULL DEFAULT 0
    )"
    $shimCommand.ExecuteNonQuery() | Out-Null
    $shimCommand.Dispose()
    if ($PassThru) {
        $db
    } else {
        $db.Close()
    }
}

function Add-ScoopDBItem($InputObject, $TypeName) {
    $db = Open-ScoopDB
}
