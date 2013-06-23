. "$(split-path $myinvocation.mycommand.path)\..\lib\core.ps1"

if(test-path $scoopdir) {
	try {
		rm -r -force $scoopdir -ea stop
	} catch {
		abort "couldn't remove $(friendly_path $scoopdir): $_"
	}
}

remove_from_path $bindir

success "scoop has been uninstalled"