function usage($text) {
	$text | sls '(?m)^# Usage: ([^\n]*)$' | % { "usage: " + $_.matches[0].groups[1].value }
}

function summary($text) {
	$text | sls '(?m)^# Summary: ([^\n]*)$' | % { $_.matches[0].groups[1].value }
}

function help($text) {
	$help_lines = $text | sls '(?ms)^# Help:(.(?!^[^#]))*' | % { $_.matches[0].value; }
	$help_lines -replace '(?ms)^#\s?(Help: )?', ''
}

function my_usage { # gets usage for the calling script
	usage (gc $myInvocation.PSCommandPath -raw)
}