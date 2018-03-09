# Usage: scoop import <filepath/filepaths> [options]
# Summary: Import exported list!
# Help: The basic way to install exported list:
#      scoop import exportedfile.txt
# It also supports for multiple file:
#      scoop import file1.txt file2.txt

function createAppsList($filePaths){
    if($filePaths){
        foreach ($file in $filePaths){
            $ext = [IO.Path]::GetExtension($file)
            if($ext -eq ".txt")
            {
                foreach ($line in (Get-Content $file | Select-Object -Unique))
                {
                    if($line -ne "") #Checks empty line!
                    {
                        if($line.StartsWith("#") -Or $line.StartsWith(";") -Or $line.StartsWith(" "))
                        {
                            continue
                        }else{
                            $appslist += $line.Split()[0] + " "
                        }
                    }
                }
            }
            else{
                $extError = "Please select .txt file!"
                Write-Error $extError
            }
        }
    }else{
        $filePathsError = "There is no file to exported!"
        Write-Error $filePathsError
    }

    $uniqueAppsList = $appslist.TrimEnd() | Select-Object -Unique

    return $uniqueAppsList
}

function importApps($appslist)
{
    $appslist.Split() | ForEach-Object{
        #echo $_ #For test purpose!
        scoop install $_
    }
}


$filePaths = $args
importApps(createAppsList($filepaths))
