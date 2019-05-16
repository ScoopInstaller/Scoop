. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\persist.ps1"
. "$psscriptroot\Scoop-TestLib.ps1"

describe 'persist parsing' -Tag 'Scoop' {
    beforeall {
        $working_dir = setup_working "persist"
    }

    context "parsing object" {
        $objfile = "$working_dir\persist-object.json"
        $objfile | should -exist
        $obj = Get-Content $objfile -Raw -Encoding UTF8 | ConvertFrom-Json -ea Stop

        it 'should handle directory' {
            # explicitly defined
            $persist_def = persist_def_obj $obj.persist_dir[0]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be $null

            # implicitly defined
            $persist_def = persist_def_obj $obj.persist_dir[1]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be $null

            # sub-dir
            $persist_def = persist_def_obj $obj.persist_dir[2]
            $persist_def.source | should -be "foo\bar"
            $persist_def.target | should -be "foo\bar"
            $persist_def.content | should -be $null

            # renaming
            $persist_def = persist_def_obj $obj.persist_dir[3]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "bar"
            $persist_def.content | should -be $null

            # ignore other params if dir
            $persist_def = persist_def_obj $obj.persist_dir[4]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.encoding | should -be $null
            $persist_def.content | should -be $null

            # passthru $method
            $persist_def = persist_def_obj $obj.persist_dir[5]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be $null
            $persist_def.method | should -be "merge"
        }

        it 'should handle file' {
            # explicitly defined
            $persist_def = persist_def_obj $obj.persist_file[0]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be ""

            # implicitly defined
            $persist_def = persist_def_obj $obj.persist_file[1]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be ""

            # passthru file comtents
            $persist_def = persist_def_obj $obj.persist_file[2]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be "file content"

            # passthru array file content
            $persist_def = persist_def_obj $obj.persist_file[3]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be "file`r`ncontent"

            # using $glue to join array file content
            $persist_def = persist_def_obj $obj.persist_file[4]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be "file content"

            # decoding BASE64 string
            $persist_def = persist_def_obj $obj.persist_file[5]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be "file`r`ncontent"

            # passthru other params
            $persist_def = persist_def_obj $obj.persist_file[6]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be "file`r`ncontent"
            $persist_def.method | should -be "update"
            $persist_def.encoding | should -be "UTF8"
        }
    }

    context 'parsing string and array of string' {
        $arrfile = "$working_dir\persist-array.json"
        $arrfile | should -exist
        $arr = Get-Content $arrfile -Raw -Encoding UTF8 | ConvertFrom-Json -ea Stop


        it 'should handle directory' {
            # parse string
            $persist_def = persist_def_arr $arr.persist_dir[0]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be $null

            # sub-folder
            $persist_def = persist_def_arr $arr.persist_dir[1]
            $persist_def.source | should -be "foo\bar"
            $persist_def.target | should -be "foo\bar"
            $persist_def.content | should -be $null

            # both specified
            $persist_def = persist_def_arr $arr.persist_dir[2]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "bar"
            $persist_def.content | should -be $null

            # null value specified
            $persist_def = persist_def_arr $arr.persist_dir[3]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be $null
        }

        it 'should handle file' {

            # no file content specified
            $persist_def = persist_def_arr $arr.persist_file[0]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be ""

            # file content specified
            $persist_def = persist_def_arr $arr.persist_file[1]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be "file content"

            # null and file content specified
            $persist_def = persist_def_arr $arr.persist_file[2]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be "file content"

            # several lines of file content specified
            $persist_def = persist_def_arr $arr.persist_file[3]
            $persist_def.source | should -be "foo"
            $persist_def.target | should -be "foo"
            $persist_def.content | should -be "file`r`ncontent"
        }
    }
}
