function help_usage($text) {
	$text | sls '(?m)^# Usage: ([^\n]*)$' | % { "usage: " + $_.matches[0].groups[1].value }
}
set-alias usage help_usage

function help_summary($text) {
	$text | sls '(?m)^# Summary: ([^\n]*)$' | % { $_.matches[0].groups[1].value }
}
set-alias summary help_summary

function help_helptext($text) {
	$help_lines = $text | sls '(?ms)^# Help:(.(?!^[^#]))*' | % { $_.matches[0].value; }
	$help_lines -replace '(?ms)^#\s?(Help: )?', ''
}
set-alias help help_helptext

function my_usage { # gets usage for the calling script
	usage (gc $myInvocation.PSCommandPath -raw)
}