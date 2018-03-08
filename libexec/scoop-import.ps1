# Usage: scoop import <filepath/filepaths> [options]
# Summary: Import exported list!
# Help: The basic way to install exported list:
#      scoop import exportedfile.txt
# It also supports for multiple file:
#      scoop import file1.txt file2.txt


function createAppsList($filePaths){
    if($filePaths){
        foreach ($file in $filePaths){
            foreach ($line in Get-Content $file)
            {
                if($line -ne "") #Checks empty line!
                {
                    $appslist += $line.Split()[0] + " "
                }
            }
        }
    }else{
        foreach ($line in Get-Content $filePaths)
        {
            if($line -ne "")
            {
                $appslist += $line.Split()[0] + " "
            }
        }
    }
  return $appslist.TrimEnd()
}

function importApps($appslist)
{
    scoop install $appslist
}


$filePaths = $args
importApps(createAppsList($filepaths))
