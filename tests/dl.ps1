$dummy = $false
$url = "http://download.microsoft.com/download/C/E/0/CE0AB8AE-E6B7-43F7-9290-F8EB0EA54FB5/IE10-Windows6.1-x64-en-us.exe"
$path = "$psscriptroot\tmp\$(split-path $url -leaf)"

write-host "downloading..." -nonewline

$left = [console]::cursorleft

if($dummy) {
    for($i = 0; $i -lt 100; $i+=2) {
        [console]::cursorleft = $left
        write-host "$i%" -nonewline
        start-sleep -m 50
    }
} else {
    $dir = split-path $path
    if(!(test-path $dir)) { mkdir $dir }
    elseif(test-path $path) { rm $path }

    $wc = new-object net.webclient
    $i = 0;
    try {
        $null = register-objectevent $wc downloadprogresschanged progress {
            [console]::cursorleft = $left
            write-host "$i`: $($eventargs.progresspercentage)%" -nonewline
            $i++;
        }
        $null = register-objectevent $wc downloadfilecompleted finished
        $wc.downloadfileasync($url, $path)
        $finished = wait-event finished
        remove-event finished
    } catch {
        "ERROR! ERROR! ERROR! press a key..."

        [console]::readkey()
    } finally {
        write-host 'clean-up'
        unregister-event finished
        unregister-event progress
        $wc.cancelasync()
        $wc.dispose()
    }
}
[console]::cursorleft = $left
write-host "done"