function manifest_path($app) { (resolve "..\bucket\$app.json") }

function parse_json($path) {
	if(!(test-path $path)) { return $null }
	gc $path -raw | convertfrom-json
}

function manifest($app) {
	parse_json (manifest_path $app)	
}

function save_installed_manifest($app, $dir) {
	cp (manifest_path $app) "$dir\manifest.json"
}

function installed_manifest($app, $version) {
	parse_json "$(versiondir $app $version)\manifest.json"
}

function save_install_info($info, $dir) {
	$info | convertto-json | out-file "$dir\install.json"
}

function install_info($app, $version) {
	parse_json "$(versiondir $app $version)\install.json"
}

function architecture {
	if([intptr]::size -eq 8) { return "64bit" }
	"32bit"
}

function arch_specific($prop, $manifest, $architecture) {
	if($manifest.$prop) { return $manifest.$prop }

	if($manifest.architecture) {
		$manifest.architecture.$architecture.$prop
	}
}

function add_installed($manifest, $props) { # add info about installation
	$installed = new-object -typename pscustomobject -prop $props
	$manifest | add-member -membertype noteproperty -name 'installed' -value $installed -passthru
}

function url($manifest, $arch) { arch_specific 'url' $manifest $arch }
function installer($manifest, $arch) { arch_specific 'installer' $manifest $arch }
function uninstaller($manifest, $arch) { arch_specific 'uninstaller' $manifest $arch }
function msi($manifest, $arch) { arch_specific 'msi' $manifest $arch }
function hash($manifest, $arch) { arch_specific 'hash' $manifest $arch }