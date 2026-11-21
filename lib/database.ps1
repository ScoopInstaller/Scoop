# Description: Functions for interacting with the Scoop database cache

<#
.SYNOPSIS
    Get SQLite .NET driver
.DESCRIPTION
    Download and extract the SQLite .NET driver and SQLite precompiled binaries.
    The SQLite version is automatically detected from the download page.
.PARAMETER Version
    System.String
    The version of the System.Data.SQLite NuGet package to download. (require version 2.0.0 or higher)
.INPUTS
    None
.OUTPUTS
    System.Boolean
    True if the SQLite .NET driver was successfully downloaded and extracted, otherwise false.
#>
function Get-SQLite {
    param (
        [string]$Version = '2.0.4'
    )
    try {
        $sqliteNetPath = "$env:TEMP\sqlite.net.zip"
        $sqliteDllPath = "$env:TEMP\sqlite.dll.zip"
        $sqliteTempPath = "$env:TEMP\sqlite"
        $sqlitePath = "$PSScriptRoot\..\supporting\sqlite"

        $arch = switch (Get-DefaultArchitecture) {
            '32bit' { 'x86' }
            '64bit' { 'x64' }
            'arm64' { 'arm64' }
            default { Write-Warning 'Unknown architecture, using x64 as fallback'; 'x64' }
        }

        Write-Host "Downloading System.Data.SQLite $Version..." -ForegroundColor DarkYellow
        Invoke-WebRequest -Uri "https://globalcdn.nuget.org/packages/system.data.sqlite.$Version.nupkg" -OutFile $sqliteNetPath

        $downloadPage = Invoke-WebRequest -Uri 'https://sqlite.org/download.html' -UseBasicParsing
        if ($downloadPage.Content -match '(?s)<!-- Download product data.*?(PRODUCT,.+?)-->') {
            $productData = $Matches[1] | ConvertFrom-Csv
        } else {
            throw 'Failed to parse SQLite download page product data'
        }
        $matchRow = $productData | Where-Object { $_.'RELATIVE-URL' -match "sqlite-dll-win-$arch-" }
        if (-not $matchRow) {
            throw "SQLite DLL for architecture $arch not found"
        }
        Write-Host "Downloading SQLite DLL $($matchRow.VERSION)..." -ForegroundColor DarkYellow
        Invoke-WebRequest -Uri "https://sqlite.org/$($matchRow.'RELATIVE-URL')" -OutFile $sqliteDllPath

        Write-Host 'Extracting libraries... ' -ForegroundColor DarkYellow -NoNewline
        $sqliteNetPath, $sqliteDllPath | Expand-Archive -DestinationPath $sqliteTempPath -Force
        $null = New-Item -Path "$sqlitePath\$arch" -ItemType Directory -Force
        Move-Item -Path "$sqliteTempPath\lib\netstandard2.0\System.Data.SQLite.dll" -Destination $sqlitePath -Force
        Move-Item -Path "$sqliteTempPath\sqlite3.dll" -Destination "$sqlitePath\$arch\e_sqlite3.dll" -Force
        Remove-Item -Path $sqliteNetPath, $sqliteDllPath, $sqliteTempPath -Recurse -Force
        Write-Host 'Done.' -ForegroundColor DarkYellow
        return $true
    } catch {
        Write-Host 'Error.' -ForegroundColor DarkRed
        return $false
    }
}

<#
.SYNOPSIS
    Open Scoop SQLite database.
.DESCRIPTION
    Open Scoop SQLite database connection and create the necessary tables if not exists.
.INPUTS
    None
.OUTPUTS
    System.Data.SQLite.SQLiteConnection
    The SQLite database connection if **PassThru** is used.
#>
function Open-ScoopDB {
    # Load System.Data.SQLite
    if (!('System.Data.SQLite.SQLiteConnection' -as [Type])) {
        try {
            if (!(Test-Path -Path "$PSScriptRoot\..\supporting\sqlite\System.Data.SQLite.dll")) {
                Get-SQLite | Out-Null
            }
            Add-Type -Path "$PSScriptRoot\..\supporting\sqlite\System.Data.SQLite.dll"
        } catch {
            throw "Scoop's Database cache requires the ADO.NET driver:`n`thttp://system.data.sqlite.org/index.html/doc/trunk/www/downloads.wiki"
        }
    }
    $dbPath = Join-Path $scoopdir 'scoop.db'
    $db = New-Object -TypeName System.Data.SQLite.SQLiteConnection
    # Wait up to 5s for the write lock instead of failing at once.
    $db.ConnectionString = "Data Source=$dbPath;BusyTimeout=5000"
    $db.ParseViaFramework = $true # Allow UNC path
    $db.Open()
    $tableCommand = $db.CreateCommand()
    $tableCommand.CommandText = "CREATE TABLE IF NOT EXISTS 'app' (
        name TEXT NOT NULL COLLATE NOCASE,
        description TEXT NOT NULL,
        version TEXT NOT NULL,
        bucket VARCHAR NOT NULL,
        manifest JSON NOT NULL,
        binary TEXT,
        shortcut TEXT,
        dependency TEXT,
        suggest TEXT,
        PRIMARY KEY (name, version, bucket)
    );
    CREATE INDEX IF NOT EXISTS idx_app_bucket_name ON app(bucket, name);"
    $tableCommand.CommandType = [System.Data.CommandType]::Text
    $tableCommand.ExecuteNonQuery() | Out-Null
    $tableCommand.Dispose()
    # TODO Add PRAGMA user_version gate before the next non-idempotent schema change (FTS5, ADD COLUMN).
    $pragmaCommand = $db.CreateCommand()
    try {
        # WAL needs shared memory and is unavailable on network shares; only relax
        # synchronous when the journal actually switched to WAL.
        $pragmaCommand.CommandText = 'PRAGMA journal_mode = WAL'
        if ($pragmaCommand.ExecuteScalar() -eq 'wal') {
            $pragmaCommand.CommandText = 'PRAGMA synchronous = NORMAL'
            $pragmaCommand.ExecuteNonQuery() | Out-Null
        }
    } catch {
        Write-Warning "Could not enable WAL journal mode: $_"
    }
    $pragmaCommand.CommandText = 'PRAGMA cache_size = -8192; PRAGMA mmap_size = 268435456;'
    $pragmaCommand.ExecuteNonQuery() | Out-Null
    $pragmaCommand.Dispose()
    return $db
}

<#
.SYNOPSIS
    Set Scoop database item(s).
.DESCRIPTION
    Insert or replace item(s) into the Scoop SQLite database.
.PARAMETER InputObject
    System.Object[]
    The database item(s) to insert or replace.
.INPUTS
    System.Object[]
.OUTPUTS
    None
#>
function Set-ScoopDBItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [psobject[]]
        $InputObject
    )

    begin {
        $db = Open-ScoopDB
        # Serializable maps to BEGIN IMMEDIATE, so the write lock is taken up front.
        # TODO Support [hashtable]$InputObject
        $dbTrans = $db.BeginTransaction([System.Data.IsolationLevel]::Serializable)
        $colName = 'name', 'description', 'version', 'bucket', 'manifest', 'binary', 'shortcut', 'dependency', 'suggest'
        $dbQuery = "INSERT OR REPLACE INTO app ($($colName -join ', ')) VALUES ($('@' + ($colName -join ', @')))"
        $dbCommand = $db.CreateCommand()
        $dbCommand.CommandText = $dbQuery
        $dbCommand.CommandType = [System.Data.CommandType]::Text
        foreach ($name in $colName) {
            [void]$dbCommand.Parameters.AddWithValue("@$name", $null)
        }
    }
    process {
        if ($null -eq $InputObject) { return }
        try {
            foreach ($item in $InputObject) {
                foreach ($name in $colName) {
                    $dbCommand.Parameters["@$name"].Value = if ($item.PSObject.Properties[$name]) {
                        $item.PSObject.Properties[$name].Value
                    } else {
                        $null
                    }
                }
                [void]$dbCommand.ExecuteNonQuery()
            }
        } catch {
            # The end block is skipped when the process block throws, so roll back and release here.
            $dbTrans.Rollback()
            $dbCommand.Dispose()
            $dbTrans.Dispose()
            $db.Dispose()
            throw
        }
    }
    end {
        try {
            $dbTrans.Commit()
        } catch {
            $dbTrans.Rollback()
            throw $_
        } finally {
            $dbCommand.Dispose()
            $dbTrans.Dispose()
            $db.Dispose()
        }
    }
}

<#
.SYNOPSIS
    Set Scoop app database item(s).
.DESCRIPTION
    Insert or replace Scoop app(s) into the database.
.PARAMETER Path
    System.String
    The path to the bucket.
.INPUTS
    None
.OUTPUTS
    None
#>
function Set-ScoopDB {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline)]
        [string[]]
        $Path
    )

    begin {
        $list = [System.Collections.Generic.List[psobject]]::new()
        $arch = Get-DefaultArchitecture
    }
    process {
        if ($Path.Count -eq 0) {
            $bucketPath = Get-LocalBucket | ForEach-Object { Find-BucketDirectory $_ }
            $Path = (Get-ChildItem $bucketPath -Filter '*.json' -Recurse).FullName
        }
        $Path = $Path | ForEach-Object {
            if (Test-Path -LiteralPath $_ -PathType Container) {
                (Get-ChildItem -LiteralPath $_ -Filter '*.json' -Recurse).FullName
            } else {
                $_
            }
        }
        $Path | ForEach-Object {
            $manifestRaw = [System.IO.File]::ReadAllText($_)
            try {
                $manifest = ConvertFrom-Json $manifestRaw -ErrorAction Stop
            } catch {
                Write-Host "Skipping invalid manifest: $_" -ForegroundColor DarkYellow
                return
            }
            if ($null -eq $manifest.version) { return }
            $list.Add([pscustomobject]@{
                    name        = $($_ -replace '.*[\\/]([^\\/]+)\.json$', '$1')
                    description = if ($manifest.description) { $manifest.description } else { '' }
                    version     = $manifest.version
                    bucket      = $($_ -replace '.*buckets[\\/]([^\\/]+)(?:[\\/].*)', '$1')
                    manifest    = $manifestRaw
                    binary      = $(
                        $result = @()
                        @(arch_specific 'bin' $manifest $arch) | ForEach-Object {
                            if ($_ -is [System.Array]) {
                                $result += "$($_[1]).$($_[0].Split('.')[-1])"
                            } else {
                                $result += $_
                            }
                        }
                        $result -replace '.*?([^\\/]+)?(\.(exe|bat|cmd|ps1|jar|py))$', '$1' -join ' | '
                    )
                    shortcut    = $(
                        $result = @()
                        @(arch_specific 'shortcuts' $manifest $arch) | ForEach-Object {
                            $result += $_[1]
                        }
                        $result -replace '.*?([^\\/]+$)', '$1' -join ' | '
                    )
                    dependency  = $manifest.depends -join ' | '
                    suggest     = @($manifest.suggest.PSObject.Properties.Value) -join ' | '
                })
        }
    }
    end {
        if ($list.Count -ne 0) {
            Set-ScoopDBItem $list
        }
    }
}

<#
.SYNOPSIS
    Find Scoop database item(s).
.DESCRIPTION
    Find item(s) from the Scoop SQLite database.
    The pattern is matched against the name, binaries, and shortcuts columns for apps.
    The manifest column is not selected: search never reads it and skipping it
    avoids moving the whole raw JSON blob per matching row.
.PARAMETER Pattern
    System.String
    The pattern to search for. If is an empty string, all items will be returned.
.PARAMETER From
    System.String[]
    The fields to search from.
.INPUTS
    System.String
.OUTPUTS
    System.Data.DataRow[]
    The found database item(s), one row per name and bucket.
#>
function Find-ScoopDBItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string]
        $Pattern,
        [Parameter(Mandatory, Position = 1)]
        [ValidateSet('name', 'binary', 'shortcut')]
        [string[]]
        $From
    )

    begin {
        $db = Open-ScoopDB
        $dbAdapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter
        $result = New-Object System.Data.DataTable
        $dbQuery = "SELECT name, description, version, bucket, binary, shortcut, dependency, suggest FROM app WHERE $(($From -join ' LIKE @Pattern OR ') + ' LIKE @Pattern')"
        $dbCommand = $db.CreateCommand()
        $dbCommand.CommandText = $dbQuery
        $dbCommand.CommandType = [System.Data.CommandType]::Text
        $dbAdapter.SelectCommand = $dbCommand
    }
    process {
        $dbCommand.Parameters.Clear()
        [void]$dbCommand.Parameters.AddWithValue('@Pattern', $(if ($Pattern -eq '') { '%' } else { '%' + $Pattern + '%' }))
        [void]$dbAdapter.Fill($result)
    }
    end {
        $dbCommand.Dispose()
        $dbAdapter.Dispose()
        $db.Dispose()
        return (Select-LatestScoopDBRow -Table $result -GroupBy @('name', 'bucket')).Rows
    }
}

<#
.SYNOPSIS
    Get Scoop database item.
.DESCRIPTION
    Get item from the Scoop SQLite database.
.PARAMETER Name
    System.String
    The name of the item to get.
.PARAMETER Bucket
    System.String
    The bucket of the item to get.
.PARAMETER Version
    System.String
    The version of the item to get. If not provided, the latest version will be returned.
.INPUTS
    System.String
.OUTPUTS
    System.Data.DataTable
    The selected database item.
#>
function Get-ScoopDBItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]
        $Name,
        [Parameter(Mandatory, Position = 1)]
        [string]
        $Bucket,
        [Parameter(Position = 2)]
        [string]
        $Version
    )

    begin {
        $db = Open-ScoopDB
        $dbAdapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter
        $result = New-Object System.Data.DataTable
        $dbQuery = 'SELECT * FROM app WHERE name = @Name AND bucket = @Bucket'
        if ($Version) {
            $dbQuery += ' AND version = @Version'
        }
        $dbCommand = $db.CreateCommand()
        $dbCommand.CommandText = $dbQuery
        $dbCommand.CommandType = [System.Data.CommandType]::Text
        $dbAdapter.SelectCommand = $dbCommand
    }
    process {
        $dbCommand.Parameters.Clear()
        [void]$dbCommand.Parameters.AddWithValue('@Name', $Name)
        [void]$dbCommand.Parameters.AddWithValue('@Bucket', $Bucket)
        if ($Version) {
            [void]$dbCommand.Parameters.AddWithValue('@Version', $Version)
        }
        [void]$dbAdapter.Fill($result)
    }
    end {
        $dbCommand.Dispose()
        $dbAdapter.Dispose()
        $db.Dispose()
        # With $Version the PRIMARY KEY yields one row; without it a name+bucket pair can span several versions.
        if ($Version) {
            Write-Output $result -NoEnumerate
        } else {
            Select-LatestScoopDBRow -Table $result
        }
    }
}

<#
.SYNOPSIS
    Get the latest row(s) from a set of Scoop database rows.
.DESCRIPTION
    Compares the `version` property of each row semantically and returns the latest row.
    When `GroupBy` is supplied, returns the latest row per group.
    Returns `$null` when no rows are provided.
.PARAMETER Rows
    System.Object[]
    The rows to evaluate for the latest version. Each row must have a `version` property.
.PARAMETER GroupBy
    System.String[]
    Optional column names used to group rows before semantic latest-row selection.
.INPUTS
    System.Object[]
.OUTPUTS
    System.Object
    The latest row, or `$null` if no rows are provided; an `ICollection` of latest rows when `GroupBy` is set.
#>
function Get-LatestScoopDBRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyCollection()]
        [object[]]
        $Rows,
        [Parameter(Position = 1)]
        [string[]]
        $GroupBy
    )

    if (-not $Rows -or $Rows.Count -eq 0) {
        return $null
    }

    # database.ps1 can be dot-sourced on its own, so load the comparer before its setting.
    if (-not ('Scoop.VersionComparer' -as [Type]) -or -not (Get-Command Get-UpdateNightlySetting -ErrorAction Ignore)) {
        . "$PSScriptRoot\versions.ps1"
    }

    $updateNightly = Get-UpdateNightlySetting

    if (-not $GroupBy -or $GroupBy.Count -eq 0) {
        $latest = $Rows[0]
        for ($i = 1; $i -lt $Rows.Count; $i++) {
            $row = $Rows[$i]
            if (([Scoop.VersionComparer]::Compare($latest.version, $row.version, $updateNightly)) -gt 0) {
                $latest = $row
            }
        }
        return $latest
    }

    $cols = @($GroupBy)
    $colCount = $cols.Count
    $latestByKey = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $latestOrder = [System.Collections.Generic.List[string]]::new()

    if ($Rows[0] -is [System.Data.DataRow]) {
        # A DataRow[string] read searches the schema, so the column ordinals are resolved once.
        $table = $Rows[0].Table
        $ordinals = [int[]]::new($colCount)
        for ($g = 0; $g -lt $colCount; $g++) {
            $ordinals[$g] = $table.Columns[$cols[$g]].Ordinal
        }
        $versionOrdinal = $table.Columns['version'].Ordinal
        foreach ($row in $Rows) {
            $key = [string]$row[$ordinals[0]]
            for ($g = 1; $g -lt $colCount; $g++) {
                $key += '|' + [string]$row[$ordinals[$g]]
            }
            if (-not $latestByKey.ContainsKey($key)) {
                $latestByKey[$key] = $row
                $latestOrder.Add($key)
                continue
            }
            if ([Scoop.VersionComparer]::Compare($latestByKey[$key][$versionOrdinal], $row[$versionOrdinal], $updateNightly) -gt 0) {
                $latestByKey[$key] = $row
            }
        }
    } else {
        foreach ($row in $Rows) {
            $key = [string]$row.$($cols[0])
            for ($g = 1; $g -lt $colCount; $g++) {
                $col = $cols[$g]
                $key += '|' + [string]$row.$col
            }
            if (-not $latestByKey.ContainsKey($key)) {
                $latestByKey[$key] = $row
                $latestOrder.Add($key)
                continue
            }
            if ([Scoop.VersionComparer]::Compare($latestByKey[$key].version, $row.version, $updateNightly) -gt 0) {
                $latestByKey[$key] = $row
            }
        }
    }
    $latestRows = [System.Collections.Generic.List[object]]::new($latestOrder.Count)
    foreach ($key in $latestOrder) {
        $latestRows.Add($latestByKey[$key])
    }
    return $latestRows
}

<#
.SYNOPSIS
    Import the latest row(s) from a Scoop database result set into a fresh DataTable.
.DESCRIPTION
    Thin wrapper over `Get-LatestScoopDBRow` that clones the schema of `Table` and
    imports the resulting row(s). Returns an empty cloned table when the source has no rows.
.PARAMETER Table
    System.Data.DataTable
    The source table returned from a Scoop database query.
.PARAMETER GroupBy
    System.String[]
    Optional column names used to group rows before semantic latest-row selection.
.OUTPUTS
    System.Data.DataTable
    A cloned table containing the latest matching row(s).
#>
function Select-LatestScoopDBRow {
    param(
        [Parameter(Mandatory)]
        [System.Data.DataTable]
        $Table,
        [string[]]
        $GroupBy
    )

    $latestRows = $Table.Clone()
    $rows = @($Table.Rows)
    if ($rows.Count -eq 0) {
        Write-Output $latestRows -NoEnumerate
        return
    }

    foreach ($row in @(Get-LatestScoopDBRow -Rows $rows -GroupBy $GroupBy)) {
        $latestRows.ImportRow($row)
    }

    Write-Output $latestRows -NoEnumerate
}

<#
.SYNOPSIS
    Remove Scoop database item(s).
.DESCRIPTION
    Remove item(s) from the Scoop SQLite database.
.PARAMETER Name
    System.String
    The name of the item to remove.
.PARAMETER Bucket
    System.String
    The bucket of the item to remove.
.INPUTS
    System.String
.OUTPUTS
    None
#>
function Remove-ScoopDBItem {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]
        $Name,
        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [string]
        $Bucket
    )

    begin {
        $db = Open-ScoopDB
        $dbTrans = $db.BeginTransaction([System.Data.IsolationLevel]::Serializable)
        $dbQuery = 'DELETE FROM app WHERE bucket = @Bucket'
        $dbCommand = $db.CreateCommand()
        $dbCommand.CommandText = $dbQuery
        $dbCommand.CommandType = [System.Data.CommandType]::Text
    }
    process {
        try {
            $dbCommand.Parameters.Clear()
            $dbCommand.CommandText = $dbQuery
            [void]$dbCommand.Parameters.AddWithValue('@Bucket', $Bucket)
            if ($Name) {
                $dbCommand.CommandText = $dbQuery + ' AND name = @Name'
                [void]$dbCommand.Parameters.AddWithValue('@Name', $Name)
            }
            $dbCommand.ExecuteNonQuery() | Out-Null
        } catch {
            $dbTrans.Rollback()
            $dbCommand.Dispose()
            $dbTrans.Dispose()
            $db.Dispose()
            throw
        }
    }
    end {
        try {
            $dbTrans.Commit()
        } catch {
            $dbTrans.Rollback()
            throw $_
        } finally {
            $dbCommand.Dispose()
            $dbTrans.Dispose()
            $db.Dispose()
        }
    }
}
