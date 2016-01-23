. "$psscriptroot\Scoop-TestLib.ps1"
. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\buckets.ps1"
. "$psscriptroot\..\lib\manifest.ps1"

describe "travel_dir" {
    beforeall {
        $working_dir = setup_working "packages"

        # copy packages from 1.0 to 1.1
        $from = "$working_dir\1.0"
        $to = "$working_dir\1.1"

        travel_dir $from $to
    }

    it 'common directory remains unchanged in destination' {
        "$to\common\version.txt" | should contain "version 1.1"
        "$to\common with spaces\version.txt" | should contain "version 1.1"
    }

    it 'common directory remains unchanged in source' {
        "$from\common" | should exist
        "$from\common with spaces" | should exist
        "$from\common\version.txt" | should contain "version 1.0"
        "$from\common with spaces\version.txt" | should contain "version 1.0"
    }

    it 'old package present in new' {
        "$to\package_a" | should exist
    }

    it 'old package doesn''t remain in old' {
        "$from\package_a" | should not exist
    }

    it 'old subdir in common dir not copied' {
        "$to\common\subdir" | should not exist
    }

    it 'common file remains unchanged in destination' {
        "$to\common_file.txt" | should contain "version 1.1"
    }
}

describe "app history" {
    it "gets all current and previous manifests of an app" {
        $history = app_history python
        $history | should not benullorempty
        write-host $history
    }
}
