# Usage: scoop import <filepath/filepaths> [options]
# Summary: Import exported list!
# Help: The basic way to install exported list:
#      scoop import exportedfile.txt


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
	return $appslist
}

function importApps($appslist)
{
    scoop install $appslist
}


$filePaths = $args
importApps(createAppsList($filepaths))

