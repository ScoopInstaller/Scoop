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

Describe 'MSIX extraction exclusions with 7-Zip' -Tag 'Scoop', 'Windows', 'Msix' {
    BeforeAll {
        . "$PSScriptRoot\..\lib\depends.ps1"
        $sevenZip = (Get-Command 7z.exe -ErrorAction Stop).Source
    }

    BeforeEach {
        Mock get_config { $false } -ParameterFilter { $name -eq 'USE_EXTERNAL_7ZIP' }
    }

    It 'restores retained filenames with <Filter> exclusions' -ForEach @(
        @{ Filter = 'default NSIS'; Excluded = 'skip%20two.nsis'; Switches = $null }
        @{ Filter = 'explicit Switches'; Excluded = 'skip%20two.txt'; Switches = '-xr!skip*' }
    ) {
        $caseDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($caseDir) | Out-Null
        $archivePath = Join-Path $caseDir 'dl.zip'
        $destination = Join-Path $caseDir 'extracted'
        Mock Get-HelperPath { $sevenZip }
        Mock Remove-Item {}
        New-TestArchive $archivePath @('app/keep%20one.txt', "app/$Excluded")

        Expand-7zipArchive $archivePath $destination -Switches $Switches

        [IO.File]::ReadAllText("$destination\app\keep one.txt") | Should-Be 'payload'
        Test-Path -LiteralPath "$destination\app\keep%20one.txt" | Should-BeFalse
        Test-Path -LiteralPath "$destination\app\$Excluded" | Should-BeFalse
        Test-Path -LiteralPath (Join-Path "$destination\app" ([uri]::UnescapeDataString($Excluded))) | Should-BeFalse
    }

    It 'preserves a pre-existing encoded <Kind> with Overwrite Skip' -ForEach @(
        @{ Kind = 'file'; Existing = 'keep%20one.txt'; Decoded = 'keep one.txt' }
        @{ Kind = 'directory'; Existing = '%40keep/old.txt'; Decoded = '@keep/old.txt' }
    ) {
        $caseDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($caseDir) | Out-Null
        $archivePath = Join-Path $caseDir 'dl.zip'
        $destination = Join-Path $caseDir 'extracted'
        $existingPath = Join-Path $destination $Existing
        [IO.Directory]::CreateDirectory((Split-Path $existingPath)) | Out-Null
        [IO.File]::WriteAllText($existingPath, 'existing')
        Mock Get-HelperPath { $sevenZip }
        Mock Remove-Item {}
        New-TestArchive $archivePath @($Existing, 'new%20two.txt')

        Expand-7zipArchive $archivePath $destination -Overwrite Skip

        [IO.File]::ReadAllText($existingPath) | Should-Be 'existing'
        Test-Path -LiteralPath (Join-Path $destination $Decoded) | Should-BeFalse
        [IO.File]::ReadAllText("$destination\new two.txt") | Should-Be 'payload'
    }
}

Describe 'MSIX filenames with <Extractor>' -ForEach @(
    @{ Extractor = 'Expand-ZipArchive' }
    @{ Extractor = 'Expand-7zipArchive' }
) -Tag 'Scoop', 'Windows', 'Msix' {
    BeforeAll {
        . "$PSScriptRoot\..\lib\depends.ps1"
        if ($Extractor -eq 'Expand-7zipArchive') {
            $sevenZip = (Get-Command 7z.exe -ErrorAction Stop).Source
        }
    }

    BeforeEach {
        $caseDir = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($caseDir) | Out-Null
        $archivePath = Join-Path $caseDir 'dl.zip'
        $destination = Join-Path $caseDir 'extracted'
        Mock get_config { $false } -ParameterFilter { $name -eq 'USE_EXTERNAL_7ZIP' }
        if ($Extractor -eq 'Expand-7zipArchive') {
            Mock Get-HelperPath { $sevenZip }
        } else {
            Mock Get-HelperPath { throw 'Built-in ZIP must not require 7-Zip' }
            Mock Get-Command { throw '7-Zip is unavailable' } -ParameterFilter { $Name -in @('7z', '7z.exe') }
        }
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

    It 'dispatches to the selected extractor despite external 7-Zip user configuration' {
        $oldConfig = $scoopConfig
        try {
            $scoopConfig = [PSCustomObject]@{ USE_EXTERNAL_7ZIP = $true }
            New-TestArchive $archivePath @('app/%40oai/package.json')
            Mock Test-HelperInstalled { $Extractor -eq 'Expand-7zipArchive' }
            Mock Expand-ZipArchive {}
            Mock Expand-7zipArchive {}
            $manifest = [PSCustomObject]@{ url = 'https://example.invalid/package.msix#/dl.zip' }

            Invoke-Extraction -Path $caseDir -Name 'dl.zip' -Manifest $manifest -Architecture '64bit'

            Should-Invoke $Extractor -Exactly -Times 1
            if ($Extractor -eq 'Expand-ZipArchive') {
                Should-Invoke Expand-7zipArchive -Exactly -Times 0
            } else {
                Should-Invoke Expand-ZipArchive -Exactly -Times 0
            }
        } finally { $scoopConfig = $oldConfig }
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
