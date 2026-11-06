BeforeAll {
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\decompress.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
    . "$PSScriptRoot\..\lib\download.ps1"

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    function New-TestArchive($Path, $Entries, $Msix = $true) {
        $archive = [IO.Compression.ZipFile]::Open($Path, 'Create')
        try {
            if ($Msix) {
                foreach ($name in @('AppxManifest.xml', 'AppxBlockMap.xml', '[Content_Types].xml')) {
                    $writer = [IO.StreamWriter]::new($archive.CreateEntry($name).Open())
                    try { $writer.Write('<Package />') } finally { $writer.Dispose() }
                }
            }
            foreach ($name in $Entries) {
                $writer = [IO.StreamWriter]::new($archive.CreateEntry($name).Open())
                try { $writer.Write('payload') } finally { $writer.Dispose() }
            }
        } finally {
            $archive.Dispose()
        }
    }
}

Describe 'MSIX filenames with <Extractor>' -ForEach @(
    @{ Extractor = 'Expand-ZipArchive' }
    @{ Extractor = 'Expand-7zipArchive' }
) -Tag 'Scoop', 'Windows', 'Msix' {
    BeforeAll {
        . "$PSScriptRoot\..\lib\depends.ps1"
        $sevenZip = (Get-Command 7z.exe -ErrorAction Stop).Source
    }

    BeforeEach {
        $caseDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($caseDir) | Out-Null
        $archivePath = Join-Path $caseDir 'dl.zip'
        $destination = Join-Path $caseDir 'extracted'
        Mock Get-HelperPath { $sevenZip }
        # Archive removal is separate from filename restoration.
        Mock Remove-Item {}
    }

    It 'restores nested scoped packages and filenames' {
        New-TestArchive $archivePath @('app/node_modules/%40oai/sky/package.json', 'app/node_modules/%40img/a%20b%5B1%5D.txt')
        & $Extractor $archivePath $destination
        [IO.File]::ReadAllText("$destination\app\node_modules\@oai\sky\package.json") | Should-Be 'payload'
        [IO.File]::ReadAllText("$destination\app\node_modules\@img\a b[1].txt") | Should-Be 'payload'
        Test-Path -LiteralPath "$destination\app\node_modules\%40oai" | Should-BeFalse
    }

    It 'decodes UTF-8 and percent characters exactly once without changing plus signs' {
        New-TestArchive $archivePath @('app/%E4%BD%A0%E5%A5%BD.txt', 'app/%2540scope/a+b%2Bc.txt')
        & $Extractor $archivePath $destination
        $unicode = [uri]::UnescapeDataString('%E4%BD%A0%E5%A5%BD.txt')
        Test-Path -LiteralPath "$destination\app\$unicode" | Should-BeTrue
        Test-Path -LiteralPath "$destination\app\%40scope\a+b+c.txt" | Should-BeTrue
        Test-Path -LiteralPath "$destination\app\@scope" | Should-BeFalse
    }

    It 'keeps percent-encoded names in ordinary ZIP files' {
        New-TestArchive $archivePath @('app/%40oai/package.json') $false
        & $Extractor $archivePath $destination
        Test-Path -LiteralPath "$destination\app\%40oai\package.json" | Should-BeTrue
        Test-Path -LiteralPath "$destination\app\@oai" | Should-BeFalse
    }

    It 'leaves format validation of non-ZIP downloads to the existing extractor' {
        [IO.File]::WriteAllText($archivePath, 'not a ZIP archive')
        @(Get-MsixEncodedPath $archivePath) | Should-BeCollection -Count 0
    }

    It 'restores adjacent encoded and literal-percent names without collisions' {
        New-TestArchive $archivePath @('app/%2540scope/literal.txt', 'app/%40scope/scoped.txt')
        & $Extractor $archivePath $destination
        Test-Path -LiteralPath "$destination\app\%40scope\literal.txt" | Should-BeTrue
        Test-Path -LiteralPath "$destination\app\@scope\scoped.txt" | Should-BeTrue
    }

    It 'uses filename restoration through the normal extraction dispatcher' {
        New-TestArchive $archivePath @('app/node_modules/%40oai/package.json')
        Mock Test-HelperInstalled { $Extractor -eq 'Expand-7zipArchive' }
        $manifest = [PSCustomObject]@{ url = 'https://example.invalid/package.msix#/dl.zip'; extract_to = 'out' }
        Invoke-Extraction -Path $caseDir -Name 'dl.zip' -Manifest $manifest -Architecture '64bit'
        Test-Path -LiteralPath "$caseDir\out\app\node_modules\@oai\package.json" | Should-BeTrue
        Should-Invoke Remove-Item -ParameterFilter { $Path -eq $archivePath }
    }

    It 'does not rename unrelated files already in the destination' {
        New-TestArchive $archivePath @('app/%40oai/package.json')
        [IO.Directory]::CreateDirectory($destination) | Out-Null
        [IO.File]::WriteAllText("$destination\unrelated%40.txt", 'existing')
        & $Extractor $archivePath $destination
        Test-Path -LiteralPath "$destination\app\@oai\package.json" | Should-BeTrue
        [IO.File]::ReadAllText("$destination\unrelated%40.txt") | Should-Be 'existing'
    }

    It 'restores names after extract_dir has been moved to the destination' {
        New-TestArchive $archivePath @('app/resources/%40oai/package.json', 'other/%40keep/file.txt')
        Mock movedir {
            param($from, $to)
            [IO.Directory]::CreateDirectory($to) | Out-Null
            Get-ChildItem -LiteralPath $from -Force | ForEach-Object {
                Move-Item -LiteralPath $_.FullName -Destination $to
            }
        }
        & $Extractor $archivePath $destination -ExtractDir 'app/resources'
        Test-Path -LiteralPath "$destination\@oai\package.json" | Should-BeTrue
        if ($Extractor -eq 'Expand-ZipArchive') {
            Test-Path -LiteralPath "$destination\_tmp\other\%40keep\file.txt" | Should-BeTrue
        }
        Test-Path -LiteralPath "$destination\@keep" | Should-BeFalse
    }

    It 'refuses decoded filename collisions before extracting' {
        New-TestArchive $archivePath @('app/%40oai/file.txt', 'app/@oai/file.txt')
        { & $Extractor $archivePath $destination } | Should-Throw
        Test-Path -LiteralPath $destination | Should-BeFalse
    }

    It 'refuses unsafe decoded paths: <Name>' -ForEach @(
        @{ Name = '../escape.txt' }
        @{ Name = 'app/%2e%2e/escape.txt' }
        @{ Name = 'app/%2Fescape.txt' }
        @{ Name = 'app/%5Cescape.txt' }
        @{ Name = 'app/name%3Astream' }
        @{ Name = 'app/%00name.txt' }
    ) {
        New-TestArchive $archivePath @($Name)
        { & $Extractor $archivePath $destination } | Should-Throw
        Test-Path -LiteralPath $destination | Should-BeFalse
    }

    It 'does not overwrite an existing decoded destination' {
        New-TestArchive $archivePath @('%40oai/file.txt')
        [IO.Directory]::CreateDirectory("$destination\@oai") | Out-Null
        [IO.File]::WriteAllText("$destination\@oai\file.txt", 'existing')
        { & $Extractor $archivePath $destination } | Should-Throw
        [IO.File]::ReadAllText("$destination\@oai\file.txt") | Should-Be 'existing'
    }
}
