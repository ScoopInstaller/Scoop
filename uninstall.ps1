. .\lib\init.ps1

if(test-path $scoopdir) {
    rm -r $scoopdir
} else {
    echo "couldn't find $(friendly_path $scoopdir)"
}


# todo: remove scoop\bin from path

success "you successfully uninstalled scoop"