. "$(split-path $myinvocation.mycommand.path)\supporting\util.ps1"

# used to work out how to modify default .vimrc using the right encoding
# does actually test any scoop code

$tmp = ensure tmp
$src = resolve fixtures\_vimrc
$dst = "$tmp\_vimrc"

if(test-path $dst) { rm $dst }

cp $src $dst

$append = "set shell=powershell.exe"
$append | out-file $dst -append -encoding ascii

if((gc $dst)[-1] -eq $append) {
    write-host "ok" -f green
} else {
    write-host ((gc $dst) | select -last 3) -f red
}
