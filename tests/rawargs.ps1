.\supporting\command_info -am "testing the params" 2>&1
.\supporting\command_info.ps1 -am "testing the params"
( & '.\supporting\command_info' -am "testing the params" ) | sort-object
( & '.\supporting\command_info.ps1' -am "testing the params" ) | sort-object
( .\supporting\command_info -am "testing the params" ) | sort-object
( .\supporting\command_info.ps1 -am "testing the params" ) | sort-object

get-childitem | .\supporting\command_info.ps1 -am "testing the params" | sort-object

.\supporting\command_info "how about a string with an 'apostrophe in its text?"