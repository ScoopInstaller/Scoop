. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\persist.ps1"
. "$psscriptroot\Scoop-TestLib.ps1"

Describe 'persist parsing' -Tag 'Scoop' {
    BeforeAll {
        $working_dir = setup_working "persist"
    }

    Context "parsing object" {
        $objfile = "$working_dir\persist-object.json"
        $objfile | Should -Exist
        $obj = Get-Content $objfile -Raw -Encoding UTF8 | ConvertFrom-Json -ea Stop

        It 'Should handle directory' {
            # explicItly defined
            $persist_def = Get-PersistentDefination $obj.persist_dir[0]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be $null

            # implicItly defined
            $persist_def = Get-PersistentDefination $obj.persist_dir[1]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be $null

            # sub-dir
            $persist_def = Get-PersistentDefination $obj.persist_dir[2]
            $persist_def.Source | Should -Be "foo\bar"
            $persist_def.Target | Should -Be "foo\bar"
            $persist_def.Content | Should -Be $null

            # renaming
            $persist_def = Get-PersistentDefination $obj.persist_dir[3]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "bar"
            $persist_def.Content | Should -Be $null

            # ignore other params if dir
            $persist_def = Get-PersistentDefination $obj.persist_dir[4]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Encoding | Should -Be $null
            $persist_def.Content | Should -Be $null

            # passthru $method
            $persist_def = Get-PersistentDefination $obj.persist_dir[5]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be $null
            $persist_def.Method | Should -Be "merge"
        }

        It 'Should handle file' {
            # explicItly defined
            $persist_def = Get-PersistentDefination $obj.persist_file[0]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be ""

            # implicItly defined
            $persist_def = Get-PersistentDefination $obj.persist_file[1]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be ""

            # passthru file comtents
            $persist_def = Get-PersistentDefination $obj.persist_file[2]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be "file content"

            # passthru array file content
            $persist_def = Get-PersistentDefination $obj.persist_file[3]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be "file`r`ncontent"

            # using $glue to join array file content
            $persist_def = Get-PersistentDefination $obj.persist_file[4]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be "file content"

            # decoding BASE64 string
            $persist_def = Get-PersistentDefination $obj.persist_file[5]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be "file`r`ncontent"

            # passthru other params
            $persist_def = Get-PersistentDefination $obj.persist_file[6]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be "file`r`ncontent"
            $persist_def.Method | Should -Be "update"
            $persist_def.Encoding | Should -Be "UTF8"
        }
    }

    Context 'parsing string and array of string' {
        $arrfile = "$working_dir\persist-array.json"
        $arrfile | Should -Exist
        $arr = Get-Content $arrfile -Raw -Encoding UTF8 | ConvertFrom-Json -ea Stop


        It 'Should handle directory' {
            # parse string
            $persist_def = Get-PersistentDefination $arr.persist_dir[0]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be $null

            # sub-folder
            $persist_def = Get-PersistentDefination $arr.persist_dir[1]
            $persist_def.Source | Should -Be "foo\bar"
            $persist_def.Target | Should -Be "foo\bar"
            $persist_def.Content | Should -Be $null

            # both specified
            $persist_def = Get-PersistentDefination $arr.persist_dir[2]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "bar"
            $persist_def.Content | Should -Be $null

            # null value specified
            $persist_def = Get-PersistentDefination $arr.persist_dir[3]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be $null
        }

        It 'Should handle file' {

            # no file content specified
            $persist_def = Get-PersistentDefination $arr.persist_file[0]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be ""

            # file content specified
            $persist_def = Get-PersistentDefination $arr.persist_file[1]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be "file content"

            # null and file content specified
            $persist_def = Get-PersistentDefination $arr.persist_file[2]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be "file content"

            # several lines of file content specified
            $persist_def = Get-PersistentDefination $arr.persist_file[3]
            $persist_def.Source | Should -Be "foo"
            $persist_def.Target | Should -Be "foo"
            $persist_def.Content | Should -Be "file`r`ncontent"
        }
    }
}
