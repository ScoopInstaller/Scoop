# Usage: scoop import <filepath/filepaths> [options]
# Summary: Import exported list!
# Help: The basic way to install exported list:
#      scoop import exportedfile.txt
# It also supports for multiple file:
#      scoop import file1.txt file2.txt


function createAppsList($filePaths) {
    if ($filePaths) {
        foreach ($file in $filePaths) {
            $ext = [IO.Path]::GetExtension($file)
            if ($ext -eq ".txt") {
                foreach ($line in (Get-Content $file | Select-Object -Unique)) {
                    if ($line -ne "") {
                        if ($line.StartsWith("#") -Or $line.StartsWith(";") -Or $line.StartsWith(" ")) {
                            continue
                        }
                        else {
                            if ($line -like '*global*') {
                                if ($line -like '*32bit*') {
                                    $appslist += $line.Split()[0] + " -g -32bit,"
                                }
                                else {
                                    $appslist += $line.Split()[0] + " -g,"
                                }
                            }
                            elseif ($line -like '*32bit*') {
                                $appslist += $line.Split()[0] + " -32bit,"
                            }
                            else {
                                $appslist += $line.Split()[0] + ","
                            }
                        }
                    }
                }
            }
            else {
                $extError = "Please select .txt file!"
                throw $extError
            }
        }
    }
    else {
        $filePathsError = "There is no file to exported!"
        throw $filePathsError
    }

    $uniqueAppsList = $appslist.TrimEnd(",") | Select-Object -Unique

    return $uniqueAppsList
}

function importApps($appslist) {
    #echo $appslist

    $appslist.Split(",") | ForEach-Object {
        #echo $_         #For test purpose!
        if ($_ -match '-g') {
            if ($_ -match '-32bit') {
                #echo $_.Split()[0] --global --arch 32bit
                scoop install $_.Split()[0] --global --arch 32bit
            }
            else {
                #echo $_.Split()[0] --global
                scoop install $_.Split()[0] --global
            }
        }
        elseif ($_ -match '-32bit') {
            #echo $_.Split()[0] -a 32bit
            scoop install $_.Split()[0] -a 32bit
        }
        else {
            #echo $_
            scoop install $_
        }
    }
}


$filePaths = $args
importApps(createAppsList($filepaths))
