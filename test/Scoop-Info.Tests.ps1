BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\buckets.ps1"
    $infoScript = "$PSScriptRoot\..\libexec\scoop-info.ps1"
}

Describe 'scoop info Source' -Tag 'Scoop' {
    BeforeEach {
        $scoopdir = "$TestDrive\scoop"
        $globaldir = "$TestDrive\global"
        $bucketsdir = "$scoopdir\buckets"
        $manifest = '{ "version": "1.0", "description": "Demo app", "url": "https://example.com/demo.zip", "hash": "0000000000000000000000000000000000000000000000000000000000000000" }'
        New-Item -ItemType Directory "$bucketsdir\main\bucket", "$TestDrive\work" -Force | Out-Null
        Set-Content "$bucketsdir\main\bucket\demo.json" $manifest
        Set-Content "$TestDrive\demo-local.json" $manifest
        Push-Location "$TestDrive\work"
    }

    AfterEach {
        Pop-Location
    }

    It 'shows the bucket of a bucket app' {
        (& $infoScript demo).Source | Should -Be 'main'
    }

    It 'shows the bucket when a folder with the app name is in the current directory' {
        New-Item -ItemType Directory "$TestDrive\work\demo" -Force | Out-Null
        (& $infoScript demo).Source | Should -Be 'main'
    }

    It 'shows the file of a local manifest' {
        (& $infoScript "$TestDrive\demo-local.json").Source | Should -Be (Convert-Path "$TestDrive\demo-local.json")
    }
}
