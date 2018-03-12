# Usage: scoop import <filepath/filepaths> [options]
# Summary: Import exported list!
# Help: The basic way to install exported list:
#      scoop import exportedfile.txt
# It also supports for multiple file:
#      scoop import file1.txt file2.txt

function createAppsList($filePaths) {
    $appList = New-Object System.Collections.ArrayList
    if ($filePaths) {
        foreach ($file in $filePaths) {
            if (checkFileExt($file)) {
                foreach ($line in (Get-Content $file | Select-Object -Unique)) {
                    if (checkEmptyLine($line)) {
                        if (checkComment($line)) {
                            continue
                        }
                        else {
                            $appList += ($line + "`r`n")
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

    $uniqueAppList = $appList | Get-Unique

    return $uniqueAppList
}

function checkFileExt ($file) {
    $ext = [IO.Path]::GetExtension($file)
    if ($ext -eq ".txt") {
        return $True
    }
    else {
        return $false
    }
}

function checkEmptyLine ($line) {
    if ($line -ne "") {
        return $True
    }
    else {
        return $False
    }
}
function checkComment ($line) {
    if ($line.StartsWith("#") -Or $line.StartsWith(";") -Or $line.StartsWith(" ")) {
        return $True
    }
    else {
        return $False
    }
}
function checkGlobal ($line) {
    if ($line.contains("*global*")) {
        return $True
    }
    else {
        return $False
    }
}

function checkArch ($line) {
    if ($line.contains("{32bit}")) {
        return $True
    }
    else {
        return $False
    }
}

function checkURL ($line) {
    if ($line.contains(".json")) {
        return $True
    }
    else {
        return $False
    }
}

function importApps($appslist) {


    $appslist | ForEach-Object {

        $globalArgs = ""
        $archArgs = ""

        if (checkAppsInstalled($_)) {
            if (checkURL($_)) {
                if (checkGlobal($_)) {
                    $globallArgs += "--global "
                }
                if (checkArch($_)) {
                    $archlArgs += "--arch 32bit "
                }

                $_ -match '\[(?<url>\S+.json)\]' > $null

                try {
                    scoop install $Matches.url $globalArgs.TrimEnd(" ") $archArgs.TrimEnd(" ")
                }
                catch {
                    $urlError = "Can't find the json file!"
                    throw $urlError
                    $installFromBucket = Read-Host -Prompt "Do you want to install from buckets? [Y/N]"

                    if ($installFromBucket -eq "Y") {
                        $_ -match '(?<appname>\S+)' > $null
                        scoop install $Matches.appname + $globalArgs.TrimEnd(" ") $archArgs.TrimEnd(" ")

                    }
                    elseif ($installFromBucket -eq "N") {
                        continue
                    }
                    else {
                        $installFromBucket = Read-Host -Prompt "Please enter proper choice: [Y/N]"
                    }

                }

            }
            else {

                if (checkGlobal($_)) {
                    $globalArgs += "--global "
                }
                if (checkArch($_)) {
                    $archArgs += "--arch 32bit "
                }

                $_ -match '(?<appname>\S+)' > $null
                scoop install $Matches.appname $globalArgs.TrimEnd(" ") $archArgs.TrimEnd(" ")
            }

        }
    }

}

function checkAppsInstalled($appslist) {
    $installedapps = Get-Content $scoopinstalledlist

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


importApps(createAppsList($filePaths))

Remove-Item $scoopinstalledlist
