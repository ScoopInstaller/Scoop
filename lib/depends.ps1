# http://www.electricmonk.nl/docs/dependency_resolving_algorithm/dependency_resolving_algorithm.html
function deps($app, $arch) {
	$resolved = new-object collections.arraylist
	dep_resolve $app $arch $resolved @()
	$resolved
}

function dep_resolve($app, $arch, $resolved, $unresolved) {
	$unresolved += $app

	$null, $manifest, $null, $null = locate $app
	if(!$manifest) { abort "couldn't find manifest for $app" }

	$deps = @(runtime_deps $manifest) + @(install_deps $manifest $arch)	| select -uniq

	foreach($dep in $deps) {
		if($resolved -notcontains $dep) {
			if($unresolved -contains $dep) {
				abort "circular dependency detected: $app -> $dep"
			}
			dep_resolve $dep $arch $resolved $unresolved
		}
	}
	$resolved.add($app) > $null
	$unresolved = $unresolved -ne $app # remove from unresolved
}

function runtime_deps($manifest) {
	if($manifest.depends) { return $manifest.depends }
}

function install_deps($manifest, $arch) {
	$deps = @()

	if(requires_7zip $manifest $arch) { $deps += "7zip" }
	if($manifest.innosetup) { $deps += "innounp" }

	$deps
}