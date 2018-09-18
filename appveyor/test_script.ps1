Write-Output $PSVersionTable
$env:failedcount = 0
$PesterOutputFile = "$TEMP\TestResults-{0}.xml" -f $PSVersionTable.PSVersion
$result = Invoke-Pester -Path test/ -OutputFile $PesterOutputFile -OutputFormat NUnitXML -PassThru
$env:failedcount = $result.failedcount
(New-Object Net.WebClient).UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $PesterOutputFile))
