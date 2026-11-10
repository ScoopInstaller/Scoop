BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    $cacheScript = "$PSScriptRoot\..\libexec\scoop-cache.ps1"
}

Describe 'scoop cache rm' -Tag 'Scoop' {
    BeforeEach {
        $cachedir = "$TestDrive\cache"
        if (Test-Path -LiteralPath $cachedir) { Remove-Item -LiteralPath $cachedir -Recurse -Force }
        New-Item -ItemType Directory $cachedir | Out-Null
        @('demo#1.0#abc.zip_', 'demo.txt', 'demo2#3.0#def.zip', 'demo2.txt', 'foo.bar#1.0#ghi.zip', 'fooXbar.txt', 'fooXbar#1.0#jkl.zip') |
            ForEach-Object { New-Item -ItemType File "$cachedir\$_" | Out-Null }

        function Get-CacheFileList { (@(Get-ChildItem -LiteralPath $cachedir).Name | Sort-Object) -join ', ' }
        function Get-SortedList([string[]] $names) { ($names | Sort-Object) -join ', ' }
    }

    It 'removes every file once with --all' {
        $errors = & $cacheScript rm --all 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
        $errors | Should-BeNull
        Get-CacheFileList | Should-BeEmptyString
    }

    It "removes only the app's own files" {
        & $cacheScript rm demo 6>&1 | Out-Null
        Get-CacheFileList | Should-Be (Get-SortedList 'demo2#3.0#def.zip', 'demo2.txt', 'foo.bar#1.0#ghi.zip', 'fooXbar.txt', 'fooXbar#1.0#jkl.zip')
    }

    It 'matches app names literally' {
        (@(& $cacheScript show foo.bar | Select-Object -ExpandProperty Name) -join ',') | Should-Be 'foo.bar'

        & $cacheScript rm foo.bar 6>&1 | Out-Null
        Get-CacheFileList | Should-Be (Get-SortedList 'demo#1.0#abc.zip_', 'demo.txt', 'demo2#3.0#def.zip', 'demo2.txt', 'fooXbar.txt', 'fooXbar#1.0#jkl.zip')
    }

    It 'removes app names with wildcard characters' {
        $zip = Join-Path $cachedir 'br[a]cket#1.0#x.zip'
        $txt = Join-Path $cachedir 'br[a]cket.txt'
        [IO.File]::WriteAllText($zip, '')
        [IO.File]::WriteAllText($txt, '')
        Test-Path -LiteralPath $zip | Should-BeTrue
        & $cacheScript rm 'br[a]cket' 6>&1 | Out-Null
        Test-Path -LiteralPath $zip | Should-BeFalse
        Test-Path -LiteralPath $txt | Should-BeFalse
    }

    It 'removes a leftover aria2 input file without a download' {
        Remove-Item -LiteralPath "$cachedir\demo#1.0#abc.zip_"
        & $cacheScript rm demo 6>&1 | Out-Null
        Test-Path -LiteralPath "$cachedir\demo.txt" | Should-BeFalse
    }
}
