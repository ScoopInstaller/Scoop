BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\system.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
    . "$PSScriptRoot\..\lib\shortcuts.ps1"
    . "$PSScriptRoot\..\lib\psmodules.ps1"
    . "$PSScriptRoot\..\lib\shim.ps1"
    . "$PSScriptRoot\..\lib\install.ps1"
    . "$PSScriptRoot\..\lib\update.ps1"
    . "$PSScriptRoot\..\lib\download.ps1" # 'Invoke-ScoopDownload'
    . "$PSScriptRoot\..\lib\decompress.ps1" # 'Invoke-Extraction'
    . "$PSScriptRoot\..\lib\json.ps1" # 'ConvertToPrettyJson'
}

Describe 'appname_from_url' -Tag 'Scoop' {
    It 'should extract the correct name' {
        appname_from_url 'https://example.org/directory/foobar.json' | Should-Be 'foobar'
    }
}

Describe 'install_app' -Tag 'Scoop' {
    BeforeEach {
        $script:appdir = Join-Path $TestDrive ([guid]::NewGuid())
        Mock versiondir { "$script:appdir\$version" }
        Mock Get-Manifest { 'foo', [PSCustomObject]@{ version = '1.0' }, 'main', $null }
        Mock Get-SupportedArchitecture { '64bit' }
        Mock error {}
    }

    It 'should report the failure without aborting the batch' {
        Mock Get-SupportedArchitecture { $null }
        $failed = @{}

        install_app 'foo' '64bit' $false @{} $failed

        Should-Invoke error -Times 1 -ParameterFilter { $msg -like "*doesn't support current architecture*" }
        $failed.Keys | Should-BeCollection -Count 1
        $failed['foo'] | Should-Be 'unsupported architecture'
    }

    It 'should report the failure and keep installing the other apps when a hook aborts' {
        Mock Get-Manifest {
            if ($app -eq 'foo') {
                'foo', [PSCustomObject]@{ version = '1.0'; pre_install = 'abort "hook failed"' }, 'main', $null
            } else {
                'bar', [PSCustomObject]@{ version = '1.0' }, 'main', $null
            }
        }
        Mock Get-SupportedArchitecture { '64bit' }
        Mock Invoke-ScoopDownload { @('foo.zip') }
        Mock Invoke-Extraction {}
        Mock Invoke-Installer { $true }
        Mock ensure_install_dir_not_in_path {}
        Mock link_current { 'C:\fake\current' }
        Mock link_app {}
        Mock save_installed_manifest {}
        Mock save_install_info {}
        Mock show_notes {}
        Mock success {}
        Mock error {}
        Mock Write-Host {}
        $failed = @{}

        install_app 'foo' '64bit' $false @{} $failed
        install_app 'bar' '64bit' $false @{} $failed

        $failed.Keys | Should-BeCollection @('foo')
        $failed['foo'] | Should-Be 'hook failed'
        Should-Invoke Invoke-Installer -Times 1 -ParameterFilter { $AppName -eq 'bar' }
        show_failed_apps $failed 'install' | Should-Be 1
    }

    It 'should record a failed extraction under the app name' {
        Mock Get-Manifest { 'foo', [PSCustomObject]@{ version = '1.0' }, 'main', $null }
        Mock Get-SupportedArchitecture { '64bit' }
        Mock Invoke-ScoopDownload { @('foo.zip') }
        Mock Invoke-Extraction { throw 'archive is broken' }
        Mock error {}
        $failed = @{}

        install_app 'foo' '64bit' $false @{} $failed

        $failed['foo'] | Should-Be 'archive is broken'
        failed_deps ([PSCustomObject]@{ depends = @('foo') }) $failed | Should-BeCollection @('foo')
        Test-Path "$script:appdir\1.0\.scoop-extracted" | Should-BeFalse
    }

    It 'should skip an app whose dependency failed' {
        Mock Get-Manifest { 'bar', [PSCustomObject]@{ version = '1.0'; depends = @('foo') }, 'main', $null }
        Mock Get-SupportedArchitecture { '64bit' }
        Mock error {}
        $failed = @{ 'foo' = 'download failed' }

        install_app 'bar' '64bit' $false @{} $failed

        Should-Invoke error -Times 1 -ParameterFilter { $msg -like '*depends on foo*' }
        $failed['bar'] | Should-Be 'dependency failed: foo'
    }



    It 'should ignore a dependency that was only skipped or blocked' {
        $manifest = [PSCustomObject]@{ depends = @('foo', 'baz', 'extras/bar') }
        $failed = @{ 'foo' = 'skipped: held to version 1.0'; 'baz' = 'blocked: running process'; 'bar (global)' = 'download failed' }

        $deps = failed_deps $manifest $failed

        $deps | Should-BeCollection -Count 1
        @($deps)[0] | Should-Be 'bar'
    }

    It 'should not ask for the manifest when the update flow installs a dependency' {
        Mock get_config { if ($name -eq 'SHOW_MANIFEST') { $true } else { $default } }
        Mock Write-Host {}
        Mock ConvertToPrettyJson { '{}' }
        Mock Invoke-ScoopDownload { throw 'stopped' }
        $asked = [ref]0
        Mock Read-Host { $asked.Value = $asked.Value + 1; 'y' }
        # the guard looks at the file the call comes from, so the second call runs from 'update.ps1'
        $caller = Join-Path $TestDrive 'update.ps1'
        [IO.File]::WriteAllText($caller, 'install_app $args[0] ''64bit'' $false $args[1] $args[2]')

        install_app 'foo' '64bit' $false @{} @{}
        $asked.Value | Should-Be 1
        $asked.Value = 0

        & $caller 'foo' @{} @{}

        $asked.Value | Should-Be 0
    }
}

Describe 'prepare_app' -Tag 'Scoop' {
    BeforeEach {
        Mock Invoke-ScoopDownload { @('foo.zip') }
        Mock Invoke-Extraction {}
    }

    It 'should reuse an extraction while the archive and the layout did not change' {
        $dir = Join-Path $TestDrive ([guid]::NewGuid())
        $manifest = [PSCustomObject]@{ version = '1.0'; hash = 'sha256:abc'; url = 'https://example.org/foo.zip' }

        $prepared = prepare_app 'foo' '64bit' $false $manifest 'main' '1.0' $true $true $dir
        prepare_app 'foo' '64bit' $false $manifest 'main' '1.0' $true $true $dir | Out-Null
        Should-Invoke Invoke-Extraction -Times 1
        Should-Invoke Invoke-ScoopDownload -Times 1

        prepare_app 'foo' '64bit' $false $manifest 'main' '1.0' $false $true $dir | Out-Null
        Should-Invoke Invoke-ScoopDownload -Times 2

        Mock Invoke-HookScript {}
        Mock Invoke-Installer { $true }
        Mock ensure_install_dir_not_in_path {}
        Mock link_current { $dir }
        Mock link_app {}
        Mock save_installed_manifest {}
        Mock save_install_info {}
        Mock show_notes {}
        Mock success {}
        install_version 'foo' $manifest '1.0' '64bit' $false 'main' $null @{} @{} $prepared.dir $prepared.fname

        Test-Path "$dir\.scoop-extracted" | Should-BeFalse
        prepare_app 'foo' '64bit' $false $manifest 'main' '1.0' $true $true $dir | Out-Null
        Should-Invoke Invoke-Extraction -Times 3
    }
}

Describe 'prepare_app over a persisted directory' -Tag 'Scoop', 'Windows' {
    It 'should keep the persisted data when the version is unpacked again' {
        $dir = Join-Path $TestDrive 'apps\foo\1.0'
        $persist = Join-Path $TestDrive 'persist\foo\data'
        New-Item -ItemType Directory -Path $persist -Force | Out-Null
        [IO.File]::WriteAllText("$persist\inner.txt", 'USER DATA')
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        cmd /c mklink /J "$dir\data" $persist | Out-Null
        New-Item -ItemType Directory -Path "$TestDrive\src\data" -Force | Out-Null
        [IO.File]::WriteAllText("$TestDrive\src\data\inner.txt", 'ARCHIVE DATA')
        Compress-Archive -Path "$TestDrive\src\*" -DestinationPath "$TestDrive\foo.zip" -Force

        Mock Invoke-ScoopDownload { Copy-Item "$TestDrive\foo.zip" -Destination (Join-Path $dir 'foo.zip'); @('foo.zip') }
        $manifest = [PSCustomObject]@{ version = '1.0'; url = 'https://example.org/foo.zip'; persist = 'data' }

        prepare_app 'foo' '64bit' $false $manifest 'main' '1.0' $false $true $dir | Out-Null

        [IO.File]::ReadAllText("$persist\inner.txt") | Should-Be 'USER DATA'
        [IO.File]::ReadAllText("$dir\data\inner.txt") | Should-Be 'ARCHIVE DATA'
    }
}


Describe 'link_app' -Tag 'Scoop' {
    BeforeAll {
        $current = '/fake/app/current'
        $version = '/fake/app/1.0'
        Mock New-ShimFromManifest {}
        Mock create_startmenu_shortcuts {}
        Mock install_psmodule {}
        Mock env_add_path {}
        Mock env_set {}
        Mock unlink_persist_data {}
        Mock persist_data {}
        Mock persist_permission {}
    }

    It 'should link through current and persist the version' {
        link_app ([PSCustomObject]@{}) $current $version '/fake/persist' $false '64bit'

        Should-Invoke New-ShimFromManifest -Times 1 -ParameterFilter { $dir -eq $current }
        Should-Invoke create_startmenu_shortcuts -Times 1 -ParameterFilter { $dir -eq $current }
        Should-Invoke install_psmodule -Times 1 -ParameterFilter { $dir -eq $current }
        Should-Invoke env_add_path -Times 1 -ParameterFilter { $dir -eq $current }
        Should-Invoke unlink_persist_data -Times 1 -ParameterFilter { $dir -eq $version }
        Should-Invoke persist_data -Times 1 -ParameterFilter { $original_dir -eq $version }
    }
}

Describe 'link_current' -Tag 'Scoop' {
    It 'should record the version as current when junctions are disabled' {
        Mock get_config { $true }
        $dir = Join-Path $TestDrive ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $record = Join-Path $dir 'scoop-install.json'
        [IO.File]::WriteAllText($record, '{}')
        (Get-Item $record).LastWriteTimeUtc = [datetime]::UtcNow.AddHours(-1)

        link_current $dir | Should-Be $dir

        ((Get-Item $record).LastWriteTimeUtc -gt [datetime]::UtcNow.AddMinutes(-1)) | Should-BeTrue
    }
}
Describe 'unlink_app' -Tag 'Scoop' {
    BeforeAll {
        $current = '/fake/app/current'
        $version = '/fake/app/1.0'
        Mock Remove-ShimFromManifest {}
        Mock rm_startmenu_shortcuts {}
        Mock unlink_current { '/fake/app/current' }
        Mock uninstall_psmodule {}
        Mock env_rm_path {}
        Mock env_rm {}
        Mock unlink_persist_data {}
    }

    It 'should unlink through current and persist the version' {
        unlink_app 'foo' ([PSCustomObject]@{}) $version '/fake/persist' $false '64bit'

        Should-Invoke uninstall_psmodule -Times 1 -ParameterFilter { $dir -eq $current }
        Should-Invoke env_rm_path -Times 1 -ParameterFilter { $dir -eq $current }
        Should-Invoke unlink_persist_data -Times 1 -ParameterFilter { $dir -eq $version }
    }
}

Describe 'remove_obsolete_wiring' -Tag 'Scoop' {
    BeforeAll {
        $old_path = Get-AbsolutePath '/fake/app/current/old'
        $ctx = [PSCustomObject]@{
            app              = 'foo'
            dir              = '/fake/app/1.0'
            persist_dir      = '/fake/persist'
            global           = $false
            architecture     = '64bit'
            new_architecture = '64bit'
        }
        Mock rm_startmenu_shortcuts {}
        Mock Remove-Path {}
        Mock Set-EnvVar {}
        Mock uninstall_psmodule {}
    }

    It 'should remove the entries the new manifest dropped' {
        $shimdir = Join-Path $TestDrive 'shims'
        New-Item -ItemType Directory -Path $shimdir -Force | Out-Null
        'path = "x"' | Set-Content (Join-Path $shimdir 'old.shim')
        'path = "y"' | Set-Content (Join-Path $shimdir 'kept.shim')
        Mock shimdir { $shimdir }

        $old = [PSCustomObject]@{ bin = @('old.exe', 'kept.exe', 'tool.exe') }
        $new = [PSCustomObject]@{ bin = @('kept.exe', 'tool.cmd') }

        remove_obsolete_wiring $ctx $old $new

        (Test-Path (Join-Path $shimdir 'old.shim')) | Should-BeFalse
        (Test-Path (Join-Path $shimdir 'kept.shim')) | Should-BeTrue
    }

    It 'should compare the new manifest with the new architecture' {
        $shimdir = Join-Path $TestDrive 'shims'
        New-Item -ItemType Directory -Path $shimdir -Force | Out-Null
        'path = "x"' | Set-Content (Join-Path $shimdir 'old.shim')
        Mock shimdir { $shimdir }

        $arm64_ctx = [PSCustomObject]@{
            app              = 'foo'
            dir              = '/fake/app/1.0'
            persist_dir      = '/fake/persist'
            global           = $false
            architecture     = 'arm64'
            new_architecture = '64bit'
        }
        $old = [PSCustomObject]@{ architecture = [PSCustomObject]@{ arm64 = [PSCustomObject]@{ bin = @('old.exe') } } }
        $new = [PSCustomObject]@{ architecture = [PSCustomObject]@{
                '64bit' = [PSCustomObject]@{ bin = @('new.exe') }
                arm64   = [PSCustomObject]@{ bin = @('old.exe') }
            } }

        remove_obsolete_wiring $arm64_ctx $old $new

        (Test-Path (Join-Path $shimdir 'old.shim')) | Should-BeFalse
    }

    It 'should remove the dropped environment entries' {
        $old = [PSCustomObject]@{ env_set = [PSCustomObject]@{ OLD_VAR = 'x' } }
        $new = [PSCustomObject]@{ env_set = [PSCustomObject]@{ KEPT_VAR = 'y' } }

        remove_obsolete_wiring $ctx $old $new

        Should-Invoke Set-EnvVar -Times 1 -ParameterFilter { $Name -eq 'OLD_VAR' }
        Should-Invoke Set-EnvVar -Times 0 -ParameterFilter { $Name -eq 'KEPT_VAR' }
    }

    It 'should remove the dropped paths' {
        $old = [PSCustomObject]@{ env_add_path = @('old', 'kept') }
        $new = [PSCustomObject]@{ env_add_path = @('kept') }

        remove_obsolete_wiring $ctx $old $new

        Should-Invoke Remove-Path -ParameterFilter { $old_path -in $Path }
    }

    It 'should remove every old path without junctions' {
        Mock get_config { $true } -ParameterFilter { $Name -eq 'NO_JUNCTION' }
        $old = [PSCustomObject]@{ env_add_path = @('scripts') }
        $new = [PSCustomObject]@{ env_add_path = @('scripts') }

        remove_obsolete_wiring $ctx $old $new

        Should-Invoke Remove-Path -ParameterFilter { (Get-AbsolutePath '/fake/app/1.0/scripts') -in $Path }
    }

    It 'should keep the module when the name did not change' {
        $old = [PSCustomObject]@{ psmodule = [PSCustomObject]@{ name = 'mod' } }
        $new = [PSCustomObject]@{ psmodule = [PSCustomObject]@{ name = 'mod' } }

        remove_obsolete_wiring $ctx $old $new

        Should-Invoke uninstall_psmodule -Times 0
    }
}

Describe 'restore_app' -Tag 'Scoop' {
    It 'should not fail when the links cannot be recreated' {
        $ctx = [PSCustomObject]@{
            app          = 'foo'
            dir          = '/fake/app/1.0'
            persist_dir  = '/fake/persist'
            global       = $false
            architecture = '64bit'
        }
        Mock installed_manifest { [PSCustomObject]@{ version = '1.0' } }
        Mock link_current { '/fake/app/current' }
        Mock link_app { throw 'cannot link' }

        restore_app $ctx ([PSCustomObject]@{ version = '1.0' }) '1.0' $null
    }

    It 'should not fail when the current link cannot be created' {
        $ctx = [PSCustomObject]@{
            app          = 'foo'
            dir          = '/fake/app/1.0'
            persist_dir  = '/fake/persist'
            global       = $false
            architecture = '64bit'
        }
        Mock installed_manifest { [PSCustomObject]@{ version = '1.0' } }
        Mock link_current { throw 'cannot link current' }
        Mock link_app {}
        Mock warn {}

        restore_app $ctx ([PSCustomObject]@{ version = '1.0' }) '1.0' $null

        Should-Invoke warn -Times 1
    }
}

Describe 'show_failed_apps' -Tag 'Scoop' {
    It 'should list the failed apps with their reason' {
        Mock error {}

        show_failed_apps @{ 'foo' = 'reason one'; 'bar' = 'reason two' } 'update'

        Should-Invoke error -Times 1 -ParameterFilter { $msg -like '*foo (reason one)*' -and $msg -like '*bar (reason two)*' }
    }

    It 'should report skipped apps separately' {
        Mock error {}
        Mock info {}

        $failed_count = show_failed_apps @{ 'foo' = 'skipped: held to version 1.0'; 'bar' = 'reason' }

        Should-Invoke error -Times 1 -ParameterFilter { $msg -like '*bar (reason)*' }
        Should-Invoke info -Times 1 -ParameterFilter { $msg -like '*foo (held to version 1.0)*' }
        $failed_count | Should-Be 1
    }

    It 'should count blocked apps towards the exit code' {
        Mock error {}
        Mock info {}

        $failed_count = show_failed_apps @{ 'foo' = 'blocked: running process' } 'update'

        Should-Invoke info -Times 1 -ParameterFilter { $msg -like '*foo (running process)*' }
        $failed_count | Should-Be 1
    }

    It 'should not count apps that were skipped on purpose' {
        Mock error {}
        Mock info {}

        $failed_count = show_failed_apps @{ 'foo' = 'skipped: held to version 1.0' } 'update'

        $failed_count | Should-Be 0
    }
}

Describe 'env add and remove path' -Tag 'Scoop', 'Windows' {
    BeforeAll {
        # test data
        $manifest = @{
            'env_add_path' = @('foo', 'bar', '.', '..')
        }
        $testdir = Join-Path $PSScriptRoot 'path-test-directory'
        $global = $false
        $persist_dir = 'D:\persist\app'
    }

    It 'should concat the correct path' {
        Mock Add-Path {}
        Mock Remove-Path {}

        # adding
        env_add_path $manifest $testdir $global
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like "$testdir\foo" }
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like "$testdir\bar" }
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like $testdir }
        Should-Invoke -CommandName Add-Path -Times 0 -ParameterFilter { $Path -like $PSScriptRoot }

        env_rm_path $manifest $testdir $global
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like "$testdir\foo" }
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like "$testdir\bar" }
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like $testdir }
        Should-Invoke -CommandName Remove-Path -Times 0 -ParameterFilter { $Path -like $PSScriptRoot }
    }

    It 'should expand $persist_dir and $dir in env_add_path' {
        Mock Add-Path {}
        Mock Remove-Path {}

        $manifest = @{ 'env_add_path' = @('$persist_dir\bin', '$dir\lib') }

        env_add_path $manifest $testdir $persist_dir $global
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like "$persist_dir\bin" }
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -like "$testdir\lib" }

        env_rm_path $manifest $testdir $persist_dir $global
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like "$persist_dir\bin" }
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -like "$testdir\lib" }
    }

    It 'should expand %VAR% from the variables env_set defines' {
        Mock Add-Path {}
        Mock Remove-Path {}

        $manifest = [PSCustomObject]@{
            env_set      = [PSCustomObject]@{ 'COOP_TEST_DIR' = '$persist_dir\bin'; 'APP-HOME' = '$persist_dir\lib' }
            env_add_path = @('%COOP_TEST_DIR%', '%APP-HOME%', '%SOME_OTHER_VAR%', '%TEMP%\bin')
        }

        env_add_path $manifest $testdir $persist_dir $global
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -contains "$persist_dir\bin" }
        Should-Invoke -CommandName Add-Path -Times 1 -ParameterFilter { $Path -contains "$persist_dir\lib" }
        Should-Invoke -CommandName Add-Path -Times 0 -ParameterFilter { $Path -contains '%SOME_OTHER_VAR%' }
        Should-Invoke -CommandName Add-Path -Times 0 -ParameterFilter { $Path -contains '%TEMP%\bin' }

        env_rm_path $manifest $testdir $persist_dir $global
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -contains "$persist_dir\bin" }
        Should-Invoke -CommandName Remove-Path -Times 1 -ParameterFilter { $Path -contains "$persist_dir\lib" }
    }

    It 'should not accept a %VAR% that points outside the app directories' {
        Mock Add-Path {}

        $manifest = [PSCustomObject]@{
            env_set      = [PSCustomObject]@{ 'COOP_TEST_OUT' = 'D:\elsewhere' }
            env_add_path = @('%COOP_TEST_OUT%')
        }

        env_add_path $manifest $testdir $persist_dir $global
        Should-Invoke -CommandName Add-Path -Times 0
    }

    It 'should keep the session %SCOOP_PATH% in sync with the stored value' {
        Mock get_config { $true } -ParameterFilter { $Name -eq 'USE_ISOLATED_PATH' }
        Mock Add-Path {}
        Mock Set-Item {}
        Mock Remove-Item {}

        $manifest = @{ 'env_add_path' = @('$dir\bin') }

        Mock Get-EnvVar { 'D:\apps\a\current' }
        env_add_path $manifest $testdir $persist_dir $global
        Should-Invoke -CommandName Set-Item -Times 1 -ParameterFilter { $Path -eq "env:$scoopPathEnvVar" -and $Value -eq 'D:\apps\a\current' }

        Mock Get-EnvVar { $null }
        env_add_path $manifest $testdir $persist_dir $global
        Should-Invoke -CommandName Remove-Item -Times 1 -ParameterFilter { $Path -eq "env:$scoopPathEnvVar" }
    }
}

Describe 'persist_def' -Tag 'Scoop' {
    It 'parses string correctly' {
        $source, $target = persist_def 'test'
        $source | Should-Be 'test'
        $target | Should-Be 'test'
    }

    It 'should handle sub-folder' {
        $source, $target = persist_def 'foo/bar'
        $source | Should-Be 'foo/bar'
        $target | Should-Be 'foo/bar'
    }

    It 'should handle arrays' {
        # both specified
        $source, $target = persist_def @('foo', 'bar')
        $source | Should-Be 'foo'
        $target | Should-Be 'bar'

        # only first specified
        $source, $target = persist_def @('foo')
        $source | Should-Be 'foo'
        $target | Should-Be 'foo'

        # null value specified
        $source, $target = persist_def @('foo', $null)
        $source | Should-Be 'foo'
        $target | Should-Be 'foo'
    }
}

Describe 'update_app' -Tag 'Scoop' {
    BeforeAll {
        . "$PSScriptRoot\..\lib\versions.ps1" # 'Select-CurrentVersion'
        . "$PSScriptRoot\..\lib\depends.ps1" # 'Get-Dependency'
        . "$PSScriptRoot\..\lib\json.ps1" # 'ConvertToPrettyJson'
    }
    BeforeEach {
        Mock Select-CurrentVersion { '3.24.0' }
        Mock test_running_process { $app -eq 'foo' }
        Mock get_config { $default }
        $script:depends = $null
        $script:architecture = '64bit'
        $script:bucket_version = '3.24.1'
        Mock Write-Host {}
        Mock warn {}
        Mock install_info { [PSCustomObject]@{ architecture = $script:architecture; url = (usermanifest $app) } }
        Mock installed_manifest { [PSCustomObject]@{ version = '3.24.0' } }
        Mock manifest { [PSCustomObject]@{ version = '3.24.0'; url = 'https://example.org/foo.zip' } }
        Mock Find-AppBucket { [PSCustomObject]@{ version = $script:bucket_version; depends = $script:depends; url = 'https://example.org/foo.zip' }, 'extras' }
        $script:appdir = Join-Path $TestDrive ([guid]::NewGuid())
        Mock versiondir { "$script:appdir\$version" }
        $script:archive_hash = 'sha256:abc'
        Mock Invoke-ScoopDownload { @('foo.zip') }
        Mock Invoke-Extraction {}
        Mock Invoke-Installer { $true }
        Mock remove_obsolete_wiring {}
        Mock restore_app {}
        Mock error {}
        Mock install_version {}
        Mock install_app {}
    }

    It 'keeps the version of an app installed from an auto-generated manifest' {
        $failed = @{}
        update_app 'foo' $false $false $false $false @{} $failed

        Should-Invoke -CommandName warn -Times 1 -ParameterFilter { $msg -like "*'foo' (3.24.0) is already installed*" }
        Should-Invoke -CommandName Find-AppBucket -Times 0
        $failed.Count | Should-Be 0
    }

    It 'upgrades an app installed from an auto-generated manifest with -f' {
        $failed = @{}
        update_app 'foo' $false $true $true $false @{} $failed

        Should-Invoke -CommandName Write-Host -Times 1 -ParameterFilter { $Object -like '*3.24.0 -> 3.24.1*' }
        Should-Invoke -CommandName Find-AppBucket -Times 1
    }

    It 'downloads the new version before it skips a running app' {
        $failed = @{}
        update_app 'foo' $false $true $true $false @{} $failed

        Should-Invoke -CommandName Invoke-ScoopDownload -Times 1
        Should-Invoke -CommandName install_app -Times 0
        Should-Invoke -CommandName test_running_process -Times 1
        $failed['foo'] | Should-Be 'blocked: running process, the new version was downloaded'
    }

    It 'should skip a running app before downloading when it is configured' {
        Mock get_config { if ($name -eq 'download_while_running') { $false } else { $default } }
        $failed = @{}
        update_app 'foo' $false $true $true $false @{} $failed

        Should-Invoke -CommandName Invoke-ScoopDownload -Times 0
        $failed['foo'] | Should-Be 'blocked: running process'
    }

    It 'should not install the app when a dependency failed' {
        Mock Get-Dependency { @('dep') }
        Mock installed { $false }
        Mock install_app { $failed['dep'] = 'download failed' }
        Mock test_running_process { $false }
        $script:depends = @('dep')
        $failed = @{}

        update_app 'foo' $false $true $true $false @{} $failed

        Should-Invoke install_version -Times 0
        $failed['foo'] | Should-Be 'dependency failed: dep'
        Should-Invoke restore_app -Times 1
    }

    It 'should install the extraction helper before it unpacks the new version' {
        $script:order = @()
        Mock Get-InstallationHelper { '7zip' }
        Mock Get-Dependency { @('7zip') }
        Mock installed { $false }
        Mock install_app { $script:order += 'helper' }
        Mock Invoke-Extraction { $script:order += 'extract' }
        Mock test_running_process { $false }
        $failed = @{}

        update_app 'foo' $false $true $true $false @{} $failed

        $script:order.IndexOf('helper') | Should-Be 0
        $script:order.IndexOf('extract') | Should-Be 1
    }

    It 'should keep the saved architecture for the old version' {
        Mock installed_manifest { [PSCustomObject]@{ version = '3.24.0' } }
        Mock test_running_process { $false }
        $script:architecture = 'arm64'
        $failed = @{}

        update_app 'foo' $false $true $true $false @{} $failed

        Should-Invoke Invoke-Installer -Times 1 -ParameterFilter { $ProcessorArchitecture -eq 'arm64' }
        Should-Invoke install_version -Times 1 -ParameterFilter { $architecture -ne 'arm64' }
    }

    It 'should download the version before it removes the old one when reinstalling it' {
        $script:order = @()
        Mock installed_manifest { [PSCustomObject]@{ version = '3.24.0' } }
        Mock Invoke-ScoopDownload { $script:order += 'download'; @('foo.zip') }
        Mock Invoke-Installer { $script:order += 'uninstall'; $true }
        Mock Move-Item {}
        Mock Remove-Item {}
        Mock test_running_process { $false }
        $script:bucket_version = '3.24.0'
        $failed = @{}

        update_app 'foo' $false $true $false $false @{} $failed

        $script:order.IndexOf('download') | Should-Be 0
        $script:order.IndexOf('uninstall') | Should-Be 1
        Should-Invoke Invoke-ScoopDownload -Times 1 -ParameterFilter { $dir -like '*_3.24.0.new' }
        Should-Invoke Remove-Item -Times 1 -ParameterFilter { $Path -like '*_3.24.0.new' }
    }


    It 'should switch to a version that is still installed instead of unpacking it' {
        Mock manifest { [PSCustomObject]@{ version = '3.24.1'; url = 'https://example.org/foo.zip' } }
        Mock link_current { $versiondir }
        Mock link_app {}
        Mock remove_obsolete_wiring {}
        Mock Invoke-HookScript {}
        $script:retained = Join-Path $TestDrive ([guid]::NewGuid())
        Mock versiondir { $script:retained }
        New-Item -ItemType Directory -Path $script:retained -Force | Out-Null
        [IO.File]::WriteAllText((Join-Path $script:retained 'scoop-manifest.json'), '{}')
        $failed = @{}

        update_app 'foo' $false $false $false $true @{} $failed

        $failed['foo'] | Should-Be 'blocked: running process'
        Should-Invoke -CommandName link_app -Times 0

        Mock test_running_process { $false }
        $failed = @{}
        update_app 'foo' $false $false $false $true @{} $failed

        Should-Invoke -CommandName Invoke-ScoopDownload -Times 0
        Should-Invoke -CommandName Invoke-Extraction -Times 0
        Should-Invoke -CommandName Invoke-Installer -Times 0
        Should-Invoke -CommandName install_version -Times 0
        Should-Invoke -CommandName link_app -Times 1 -ParameterFilter { $original_dir -eq $script:retained }
        Should-Invoke -CommandName remove_obsolete_wiring -Times 1 -ParameterFilter { $ctx.new_architecture -eq '64bit' }
        $failed.Count | Should-Be 0

        Mock installed_manifest { [PSCustomObject]@{ version = '3.24.0'; depends = @('dep') } }
        Mock Get-Dependency { @('dep') }
        Mock installed { $false }
        Mock install_app {}
        $failed = @{}
        update_app 'foo' $false $false $false $false @{} $failed

        Should-Invoke -CommandName install_app -Times 1 -ParameterFilter { $app -eq 'dep' }

        # a dependency that is already installed keeps its bucket, which may be gone
        Mock installed { $true }
        Mock Get-Dependency { throw 'no manifest' }
        $failed = @{}
        update_app 'foo' $false $false $false $false @{} $failed

        $failed.Count | Should-Be 0

        # the switch can fail after it linked the target version
        Mock installed_manifest { [PSCustomObject]@{ version = $version } }
        Mock link_app { throw 'missing target' }
        $failed = @{}
        update_app 'foo' $false $false $false $false @{} $failed

        $failed['foo'] | Should-Be 'missing target'
        Should-Invoke -CommandName remove_obsolete_wiring -Times 1 -ParameterFilter { $old_manifest.version -eq '3.24.1' -and $new_manifest.version -eq '3.24.0' }
        Should-Invoke -CommandName restore_app -Times 1

        # nothing is downloaded, so the new manifest need not support the architecture
        Mock Get-SupportedArchitecture { $null }
        Mock link_app {}
        $failed = @{}
        update_app 'foo' $false $false $false $false @{} $failed

        $failed.Count | Should-Be 0
        Should-Invoke -CommandName Invoke-ScoopDownload -Times 0

        # without a retained version the architecture has to be supported
        Remove-Item (Join-Path $script:retained 'scoop-manifest.json')
        $failed = @{}
        update_app 'foo' $false $false $false $false @{} $failed

        $failed['foo'] | Should-Be 'unsupported architecture'
    }

    It 'updates the app when its pre_uninstall hook stopped it' {
        $script:hookRan = $false
        Mock Invoke-HookScript { $script:hookRan = $true }
        Mock test_running_process { -not $script:hookRan }
        $failed = @{}

        update_app 'foo' $false $true $false $true @{} $failed

        Should-Invoke -CommandName install_version -Times 1
        $failed.Count | Should-Be 0
    }

    It 'does not remove the old version when the extraction fails' {
        Mock Invoke-Extraction { throw 'archive is broken' }
        $failed = @{}

        { update_app 'foo' $false $true $false $true @{} $failed } | Should-Throw '*archive is broken*'

        Should-Invoke -CommandName Invoke-Installer -Times 0
    }
}

Describe 'update_apps' -Tag 'Scoop' {
    It 'should keep updating the other apps when one of them is blocked' {
        Mock update_app { if ($app -eq 'foo') { $failed['foo'] = 'blocked: running process' } }
        Mock error {}
        Mock info {}
        $failed = @{}

        update_apps @(@('foo', $false), @('bar', $false)) $false $false $false @{} $failed

        Should-Invoke update_app -Times 2
        show_failed_apps $failed 'update' | Should-Be 1
    }

    It 'should keep updating the other apps when one of them aborts' {
        Mock update_app { if ($app -eq 'foo') { abort 'hook failed' } }
        Mock error {}
        $failed = @{}

        update_apps @(@('foo', $false), @('bar', $false)) $false $false $false @{} $failed

        $failed['foo'] | Should-Be 'hook failed'
        Should-Invoke update_app -Times 2
        show_failed_apps $failed 'update' | Should-Be 1
    }
}
Describe 'Invoke-HookScript' -Tag 'Scoop' {
    It 'should fail the hook instead of the whole run when it aborts' {
        Mock Write-Host {}
        $manifest = [PSCustomObject]@{ pre_install = 'abort "hook failed"' }

        { Invoke-HookScript -HookType 'pre_install' -Manifest $manifest -ProcessorArchitecture '64bit' } | Should-Throw '*hook failed*'
    }
}
