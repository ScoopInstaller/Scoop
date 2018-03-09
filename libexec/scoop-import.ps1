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
                                if ($line -like '*http*') {
                                    if ($line -like '*32bit*') {
                                        $appslist += $line.Split()[0] + " -g " + $line.Split()[3] + " -32bit,"
                                    }
                                    else {
                                        $appslist += $line.Split()[0] + " -g " + $line.Split()[3] + ","
                                    }
                                }
                                else {
                                    $appslist += $line.Split()[0] + " -g,"
                                }
                            }
                            elseif ($line -like '*http*') {
                                $appslist += $line.Split()[0] + " " + $line.Split()[2] + ","
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

    $appslist.Split(",") | ForEach-Object {

        #echo $_         #For test purpose!

        if (checkAppsInstalled($_) -eq $True) {
            if ($_ -match '-g') {
                if ($_ -match '\[http') {
                    if ($_ -match '-32bit') {
                        #echo $_.Split()[2].TrimStart("[").TrimEnd("]") --global --arch 32bit
                        scoop install $_.Split()[2].TrimStart("[").TrimEnd("]") --global --arch 32bit
                    }
                    else {
                        #echo $_.Split()[2].TrimStart("[").TrimEnd("]") --global
                        scoop install $_.Split()[2].TrimStart("[").TrimEnd("]") --global
                    }
                }
                else {
                    #echo $_.Split()[0] --global
                    scoop install $_.Split()[0] --global
                }
            }
            elseif ($_ -match '\[http') {
                #echo $_.Split()[1].TrimStart("[").TrimEnd("]")
                scoop install $_.Split()[1].TrimStart("[").TrimEnd("]")
            }
            elseif ($_ -match '-32bit') {
                #echo $_.Split()[0] --arch 32bit
                scoop install $_.Split()[0] --arch 32bit
            }
            else {
                #echo $_
                scoop install $_
            }
        }else{
            Write-Host($_.Split()[0] + " is already installed!")
        }

    }
}

function checkAppsInstalled($appslist) {
    $installedapps = Get-Content $scoopinstalledlist

    #echo $scoopinstalledlist

    $installedapps | ForEach-Object {
        $installedappslist += $_.Split()[0] + " "
    }

    $appslist.Split(",") | ForEach-Object {
        if ($installedappslist -match $_.Split()[0]) {
            return $False
        }
        else {
            return $True
        }
    }
}

$filePaths = $args
$scoopinstalledlist = "scoopinstalledlist.txt"
scoop export > $scoopinstalledlist | Out-Null

importApps(createAppsList($filepaths))

Remove-Item $scoopinstalledlist

