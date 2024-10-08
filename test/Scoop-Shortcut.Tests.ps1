BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\system.ps1"
    . "$PSScriptRoot\..\lib\install.ps1"
    . "$PSScriptRoot\..\lib\shortcuts.ps1"
    . "$PSScriptRoot\..\lib\manifest.ps1"
}

Describe 'Shortcut variable substitution' -Tag 'Scoop', 'ScoopShortcut' {
    BeforeAll {
        $working_dir = setup_working 'shortcut_substitution'
        Mock shortcut_folder { "$working_dir\startmenu" } -Verifiable -ParameterFilter { $global -eq $false }
        $original_dir = "$working_dir\vscode\1.94.0"
        $dir = link_current $original_dir
        $persist_dir = "$working_dir\persist"
        $startmenu_dir = "$working_dir\startmenu"
        $sh = New-Object -ComObject WScript.Shell
    }

    AfterAll {
        # fix remove-item access denied error
        unlink_current $original_dir
    }

    It 'should handle noramly installed program' {
        create_startmenu_shortcuts @{
            'shortcuts' = (
                , ('code.txt', 'VSCode')
            )
        } $dir $false '64bit'
        $target = $sh.CreateShortcut("$startmenu_dir\VSCode.lnk")
        $target.TargetPath | Should -Be "$dir\code.txt"
    }

    It 'should substitute variables in arguments' {
        create_startmenu_shortcuts @{
            'shortcuts' = (
                , ('code.txt', 'arg', '-dir=$dir -original_dir=$original_dir -persist_dir=$persist_dir')
            )
        } $dir $false '64bit'
        $target = $sh.CreateShortcut("$startmenu_dir\arg.lnk")
        $target.TargetPath | Should -Be "$dir\code.txt"
        $target.Arguments | Should -Be "-dir=$dir -original_dir=$original_dir -persist_dir=$persist_dir"
    }

    It 'should substitute variables $dir in target' {
        create_startmenu_shortcuts @{
            'shortcuts' = (
                , ('$dir\code.txt', 'target_dir')
            )
        } $dir $false '64bit'
        $target = $sh.CreateShortcut("$startmenu_dir\target_dir.lnk")
        $target.TargetPath | Should -Be "$dir\code.txt"
        $target.Arguments | Should -Be ''
    }
    It 'should substitute variables $original_dir in target' {
        create_startmenu_shortcuts @{
            'shortcuts' = (
                , ('$original_dir\code.txt', 'target_original')
            )
        } $dir $false '64bit'
        $target = $sh.CreateShortcut("$startmenu_dir\target_original.lnk")
        $target.TargetPath | Should -Be "$original_dir\code.txt"
        $target.Arguments | Should -Be ''
    }
}
