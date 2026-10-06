BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    $cacheScript = "$PSScriptRoot\..\libexec\scoop-cache.ps1"
}

Describe 'scoop cache rm' -Tag 'Scoop' {
    BeforeEach {
        $cachedir = "$TestDrive\cache"
        if (Test-Path $cachedir) { Remove-Item $cachedir -Recurse -Force }
        New-Item -ItemType Directory $cachedir | Out-Null
        # An interrupted aria2 download leaves a partial file and the aria2 input file '<app>.txt'
        @('demo#1.0#abc.zip_', 'demo.txt', 'demo2#3.0#def.zip', 'demo2.txt', 'foo.bar#1.0#ghi.zip', 'fooXbar.txt') |
            ForEach-Object { New-Item -ItemType File "$cachedir\$_" | Out-Null }

        function Get-CacheFileList { (@(Get-ChildItem $cachedir).Name | Sort-Object) -join ', ' }
        function Get-SortedList([string[]] $names) { ($names | Sort-Object) -join ', ' }
    }

    It 'removes every file once with --all' {
        $errors = & $cacheScript rm --all 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
        $errors | Should -BeNullOrEmpty
        Get-CacheFileList | Should -BeNullOrEmpty
    }

    It "removes the app's downloads and its aria2 input file, and nothing else" {
        $errors = & $cacheScript rm demo 2>&1 | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
        $errors | Should -BeNullOrEmpty
        Get-CacheFileList | Should -Be (Get-SortedList 'demo2#3.0#def.zip', 'demo2.txt', 'foo.bar#1.0#ghi.zip', 'fooXbar.txt')
    }

    It 'removes a leftover aria2 input file without a download' {
        Remove-Item "$cachedir\demo#1.0#abc.zip_"
        & $cacheScript rm demo 6>&1 | Out-Null
        Test-Path "$cachedir\demo.txt" | Should -BeFalse
    }

    It 'matches app names literally' {
        & $cacheScript rm foo.bar 6>&1 | Out-Null
        Get-CacheFileList | Should -Be (Get-SortedList 'demo#1.0#abc.zip_', 'demo.txt', 'demo2#3.0#def.zip', 'demo2.txt', 'fooXbar.txt')
    }
}
