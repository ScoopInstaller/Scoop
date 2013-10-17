. "$psscriptroot/../lib/core.ps1"

$text = "This line is exactly seventy-nine characters wide and so it shouldn't wrap now.

Does it handle the newline character correctly?

This line is quite long enough to wrap around at least once, twice. But not three times: that would be too many times for a line this length of 174 characters to wrap around."

wraptext $text 80