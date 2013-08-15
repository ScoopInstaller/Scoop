function cache_path($app, $version, $url) {
	"$cachedir\$app#$version#$($url -replace '[^\w\.\-]+', '_')"
}

function dl_with_cache($app, $version, $url, $to) {
	$cached = fullpath (cache_path $app $version $url)
	if(!(test-path $cached)) {
		$null = ensure $cachedir
		write-host "downloading $url..." -nonewline
		dl_progress $url "$cached.download"
		mv "$cached.download" $cached
		write-host "done"
	} else { write-host "loading $url from cache..."}
	cp $cached $to
}

function dl_progress($url, $to) {
	$left = [console]::cursorleft

	$wc = new-object net.webclient
	register-objectevent $wc downloadprogresschanged progress | out-null
	register-objectevent $wc downloadfilecompleted complete | out-null
	try {
		$wc.downloadfileasync($url, $to)

		function is_complete {
			try { get-event complete -ea stop; $true } catch { $false }
		}

		$last_p = -1
		while(!(is_complete)) {
			$e = wait-event progress
			remove-event progress
			$p = $e.sourceeventargs.progresspercentage
			if($p -ne $last_p) {
				[console]::cursorleft = $left
				write-host "$p%" -nonewline
				$last_p = $p
			}
		}
		remove-event complete
	} finally {
		remove-event *
		unregister-event progress
		unregister-event complete
		
		$wc.cancelasync()
		$wc.dispose()
	}
	[console]::cursorleft = $left
}

function dl_urls($app, $version, $manifest, $architecture, $dir) {
	# can be multiple urls: if there are, then msi or installer should go last,
	# so that $fname is set properly
	$urls = @(url $manifest $architecture)

	$fname = $null

	foreach($url in $urls) {
		$fname = split-path $url -leaf

		dl_with_cache $app $version $url "$dir\$fname"

		check_hash "$dir\$fname" $url $manifest $architecture

		# extract
		if($fname -match '\.zip$') { # unzip
			write-host "extracting..." -nonewline
			# use tmp directory and copy so we can prevent 'folder merge' errors when multiple URLs
			$null = mkdir "$dir\_scoop_unzip"
			unzip "$dir\$fname" "$dir\_scoop_unzip" (extract_dir $manifest $architecture)
			cp "$dir\_scoop_unzip\*" "$dir" -r -force
			rm -r -force "$dir\_scoop_unzip"
			rm "$dir\$fname"
			write-host "done"
		} elseif(requires_7zip $fname) { # 7zip
			if(!(7zip_installed)) {
				warn "aborting: you'll need to run 'scoop uninstall $app' to clean up"
				abort "7-zip is required. you can install it with 'scoop install 7zip'"
			}
			$to = $dir
			$extract_dir = extract_dir $manifest $architecture
			if($extract_dir) {
				$to = "$dir\_scoop_extract"
			}
			extract_7zip "$dir\$fname" $to
			if($extract_dir) {
				gci "$to\$extract_dir" -r | mv -dest "$dir" -force
				rm -r -force "$to"
			}			
		}
	}

	$fname # returns the last downloaded file
}

function is_in_dir($dir, $file) {
	$file = "$(fullpath $file)"
	$dir = "$(fullpath $dir)"
	$file -match "^$([regex]::escape("$dir\"))"
}

# hashes
function hash_for_url($manifest, $url, $arch) {
	$hashes = @(hash $manifest $arch) | ? { $_ -ne $null };

	if($hashes.length -eq 0) { return $null }

	$urls = @(url $manifest $arch)

	$index = [array]::indexof($urls, $url)
	if($index -eq -1) { abort "couldn't find hash in manifest for $url" }
	
	@($hashes)[$index]
}

function check_hash($file, $url, $manifest, $arch) {
	$hash = hash_for_url $manifest $url $arch
	if(!$hash) {
		warn "warning: no hash in manifest. sha256 is:`n$(compute_hash (fullpath $file) 'sha256')"
		return
	}

	write-host "checking hash..." -nonewline
	$type, $expected = $hash.split(':')
	if(!$expected) {
		# no type specified, assume sha256
		$type, $expected = 'sha256', $type
	}

	if(@('md5','sha1','sha256') -notcontains $type) { "hash type $type isn't supported"	}
	
	$actual = compute_hash (fullpath $file) $type

	if($actual -ne $expected) {
		abort "hash check failed for $url. expected: $($expected), actual: $($actual)!"
	}
	write-host "ok"
}

function compute_hash($file, $algname) {
	$alg = [system.security.cryptography.hashalgorithm]::create($algname)
	$fs = [system.io.file]::openread($file)
	try {
		$hexbytes = $alg.computehash($fs) | % { $_.tostring('x2') }
		[string]::join('', $hexbytes)
	} finally {
		$fs.dispose()
		$alg.dispose()
	}
}

# for dealing with installers
function args($config, $dir) {
	if($config) { return $config | % { (format $_ @{'dir'=$dir}) } }
	@()
}

function run($exe, $arg, $msg, $continue_exit_codes) {
	write-host $msg -nonewline
	try {
		$proc = start-process $exe -wait -ea stop -passthru -arg $arg
		if($proc.exitcode -ne 0) {
			if($continue_exit_codes -and ($continue_exit_codes.containskey($proc.exitcode))) {
				warn $continue_exit_codes[$proc.exitcode]
				return $true
			}
			write-host "exit code was $($proc.exitcode)"; return $false
		}
	} catch {
		write-host -f darkred $_.exception.tostring()
		return $false
	}
	write-host "done"
	return $true
}

function run_installer($fname, $manifest, $architecture, $dir) {
	# MSI or other installer
	$msi = msi $manifest $architecture
	$installer = installer $manifest $architecture

	if($msi) { 
		install_msi $fname $dir $msi
	} elseif($installer) {
		install_exe $fname $dir $installer
	}
}

function install_msi($fname, $dir, $msi) {
	$msifile = "$dir\$(coalesce $msi.file "$fname")"
	if(!(is_in_dir $dir $msifile)) {
		abort "error in manifest: MSI file $msifile is outside the app directory"
	}
	if(!($msi.code)) { abort "error in manifest: couldn't find MSI code"}
	$logfile = "$dir\install.log"

	$arg = @("/i `"$msifile`"", '/norestart', "/lvp `"$logfile`"", "TARGETDIR=`"$dir`"",
		"INSTALLDIR=`"$dir`"") + @(args $msi.args $dir)

	if($msi.silent) { $arg += '/qn', 'ALLUSERS=2', 'MSIINSTALLPERUSER=1' }
	else { $arg += '/qb-!' }

	$continue_exit_codes = @{ 3010 = "a restart is required to complete installation" }

	$installed = run 'msiexec' $arg "running installer..." $continue_exit_codes
	if(!$installed) {
		abort "installation aborted. you might need to run 'scoop uninstall $app' before trying again."
	}
	rm $logfile
	rm $msifile
}

function install_exe($fname, $dir, $installer) {
	$exe = "$dir\$(coalesce $installer.exe "$fname")"
	if(!(is_in_dir $dir $exe)) {
		abort "error in manifest: installer $exe is outside the app directory"
	}
	$arg = args $installer.args $dir
	$installed = run $exe $arg "running installer..."
	if(!$installed) {
		abort "installation aborted. you might need to run 'scoop uninstall $app' before trying again."
	}
	rm $exe
}

function run_uninstaller($manifest, $architecture, $dir) {
	$msi = msi $manifest $architecture
	$uninstaller = uninstaller $manifest $architecture

	if($msi -or $uninstaller) {
		$exe = $null; $arg = $null; $continue_exit_codes = @{}

		if($msi) {
			$code = $msi.code
			$exe = "msiexec";
			$arg = @("/norestart", "/x $code")
			if($msi.silent) {
				$arg += '/qn', 'ALLUSERS=2', 'MSIINSTALLPERUSER=1'
			} else {
				$arg += '/qb-!'
			}

			$continue_exit_codes.1605 = 'not installed, skipping'
			$continue_exit_codes.3010 = 'restart required'
		} elseif($uninstaller) {
			$exe = "$dir\$($uninstaller.exe)"
			$arg = args $uninstaller.args
			if(!(is_in_dir $dir $exe)) {
				warn "error in manifest: installer $exe is outside the app directory, skipping"
				$exe = $null;
			} elseif(!(test-path $exe)) {
				warn "uninstaller $exe is missing, skipping"
				$exe = $null;
			}
		}

		if($exe) {
			$uninstalled = run $exe $arg "running uninstaller..." $continue_exit_codes
			if(!$uninstalled) { abort "uninstallation aborted."	}
		}
	}
}

function create_shims($manifest, $dir) {
	$manifest.bin | ?{ $_ -ne $null } | % {
		echo "creating shim for $_"

		# check valid bin
		$bin = "$dir\$_"
		if(!(is_in_dir $dir $bin)) {
			abort "error in manifest: bin '$_' is outside the app directory"
		}
		if(!(test-path $bin)) { abort "can't shim $_`: file doesn't exist"}

		shim "$dir\$_"
	}
}
function rm_shims($manifest) {
	$manifest.bin | ?{ $_ -ne $null } | % {
		$shim = "$shimdir\$(strip_ext(fname $_)).ps1"
		$shim_cmd = "$(strip_ext $shim).cmd"

		if(!(test-path $shim)) { # handle no shim from failed install
			warn "shim for $_ is missing, skipping"
		} else {
			echo "removing shim for $_"
			rm $shim
		}

		if(test-path $shim_cmd) { rm $shim_cmd }
	}
}

# for installers that insist on changing path
function ensure_install_dir_not_in_path($dir) {
	$user_path = (env 'path')
	$machine_path = [environment]::getEnvironmentVariable('path', 'Machine')

	$fixed, $removed = find_dir_or_subdir $user_path "$dir"
	if($removed) {
		$removed | % { "installer added $(friendly_path $_) to path, removing"}
		env 'path' $fixed
	}

	$fixed, $removed = find_dir_or_subdir $machine_path "$dir"
	if($removed) {
		$removed | % { warn "installer added $_ to system path: you might want to remove this manually (requires admin permission)"}
	}
}

function find_dir_or_subdir($path, $dir) {
	$dir = $dir.trimend('\')
	$fixed = @()
	$removed = @() 
	$path.split(';') | % {
		if($_) {
			if(($_ -eq $dir) -or ($_ -like "$dir\*")) { $removed += $_ }
			else { $fixed += $_ }
		}
	}
	return [string]::join(';', $fixed), $removed
}

function add_env_path($manifest, $dir) {
	$manifest.add_env_path | ? { $_ } | % {
		$path_dir = "$dir\$($_)"
		if(!(is_in_dir $dir $path_dir)) {
			abort "error in manifest: add_to_path '$_' is outside the app directory"
		}
		ensure_in_path $path_dir
	}
}
function rm_env_path($manifest, $dir) {
	# remove from path
	$manifest.add_env_path | ? { $_ } | % {
		$path_dir = "$dir\$($_)"
		remove_from_path $path_dir
	}
}

function set_env($manifest, $dir) {
	if($manifest.set_env) {
		$manifest.set_env | gm -member noteproperty | % {
			$name = $_.name;
			$val = format $manifest.set_env.$($_.name) @{ "dir" = $dir }
			env $name $val
			sc env:\$name $val
		}
	}
}
function rm_env($manifest) {
	if($manifest.set_env) {
		$manifest.set_env | gm -member noteproperty | % {
			$name = $_.name;
			env $name $null
			if(test-path env:\$name) { rm env:\$name }
		}
	}
}

function post_install($manifest) {
	$manifest.post_install | ? {$_ } | % {
		echo "running post-install script..."
		iex $_
	}
}

function show_notes($manifest) {
	if($manifest.notes) {
		echo "Notes"
		echo "-----"
		echo $manifest.notes
	}
}