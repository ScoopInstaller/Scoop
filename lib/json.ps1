# Convert objects to pretty json
# Only needed until PowerShell ConvertTo-Json will be improved https://github.com/PowerShell/PowerShell/issues/2736
# https://github.com/PowerShell/PowerShell/issues/2736 was fixed in pwsh
# Still needed in normal powershell

function ConvertToPrettyJson {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory, ValueFromPipeline)]
        $data
    )

    Process {
        $data = normalize_values $data

        # convert to string
        [String]$json = $data | ConvertTo-Json -Depth 8 -Compress
        [String]$output = ''

        # state
        [String]$buffer = ''
        [Int]$depth = 0
        [Bool]$inString = $false

        # configuration
        [String]$indent = ' ' * 4
        [Bool]$unescapeString = $true
        [String]$eol = "`r`n"

        for ($i = 0; $i -lt $json.Length; $i++) {
            # read current char
            $buffer = $json.Substring($i, 1)

            $objectStart = !$inString -and $buffer.Equals('{')
            $objectEnd = !$inString -and $buffer.Equals('}')
            $arrayStart = !$inString -and $buffer.Equals('[')
            $arrayEnd = !$inString -and $buffer.Equals(']')
            $colon = !$inString -and $buffer.Equals(':')
            $comma = !$inString -and $buffer.Equals(',')
            $quote = $buffer.Equals('"')
            $escape = $buffer.Equals('\')

            if ($quote) {
                $inString = !$inString
            }

            # skip escape sequences
            if ($escape) {
                $buffer = $json.Substring($i, 2)
                ++$i

                # Unescape unicode
                if ($inString -and $unescapeString) {
                    if ($buffer.Equals('\n')) {
                        $buffer = "`n"
                    } elseif ($buffer.Equals('\r')) {
                        $buffer = "`r"
                    } elseif ($buffer.Equals('\t')) {
                        $buffer = "`t"
                    } elseif ($buffer.Equals('\u')) {
                        $buffer = [regex]::Unescape($json.Substring($i - 1, 6))
                        $i += 4
                    }
                }

                $output += $buffer
                continue
            }

            # indent / outdent
            if ($objectStart -or $arrayStart) {
                ++$depth
            } elseif ($objectEnd -or $arrayEnd) {
                --$depth
                $output += $eol + ($indent * $depth)
            }

            # add content
            $output += $buffer

            # add whitespace and newlines after the content
            if ($colon) {
                $output += ' '
            } elseif ($comma -or $arrayStart -or $objectStart) {
                $output += $eol
                $output += $indent * $depth
            }
        }

        return $output
    }
}

function json_path([String] $json, [String] $jsonpath, [Hashtable] $substitutions) {
    Add-Type -Path "$psscriptroot\..\supporting\validator\bin\Newtonsoft.Json.dll"
    if ($null -ne $substitutions) {
        $jsonpath = substitute $jsonpath $substitutions ($jsonpath -like "*=~*")
    }
    try {
        $obj = [Newtonsoft.Json.Linq.JObject]::Parse($json)
    } catch [Newtonsoft.Json.JsonReaderException] {
        try {
            $obj = [Newtonsoft.Json.Linq.JArray]::Parse($json)
        } catch [Newtonsoft.Json.JsonReaderException] {
            return $null
        }
    }

    try {
        try {
            $result = $obj.SelectToken($jsonpath, $true)
        } catch [Newtonsoft.Json.JsonException] {
            return $null
        }
        return $result.ToString()
    } catch [System.Management.Automation.MethodInvocationException] {
        write-host -f DarkRed $_
        return $null
    }

    return $null
}

function json_path_legacy([String] $json, [String] $jsonpath, [Hashtable] $substitutions) {
    $result = $json | ConvertFrom-Json -ea stop
    $isJsonPath = $jsonpath.StartsWith('$')
    $jsonpath.split('.') | ForEach-Object {
        $el = $_

        # substitute the basename and version varibales into the jsonpath
        if ($null -ne $substitutions) {
            $el = substitute $el $substitutions
        }

        # skip $ if it's jsonpath format
        if ($el -eq '$' -and $isJsonPath) {
            return
        }

        # array detection
        if ($el -match '^(?<property>\w+)?\[(?<index>\d+)\]$') {
            $property = $matches['property']
            if ($property) {
                $result = $result.$property[$matches['index']]
            } else {
                $result = $result[$matches['index']]
            }
            return
        }

        $result = $result.$el
    }
    return $result
}

function normalize_values([psobject] $json) {
    # Iterate Through Manifest Properties
    $json.PSObject.Properties | ForEach-Object {
        # Recursively edit psobjects
        # If the values is psobjects, its not normalized
        # For example if manifest have architecture and it's architecture have array with single value it's not formatted.
        # @see https://github.com/lukesampson/scoop/pull/2642#issue-220506263
        if ($_.Value -is [System.Management.Automation.PSCustomObject]) {
            $_.Value = normalize_values $_.Value
        }

        # Process String Values
        if ($_.Value -is [String]) {

            # Split on new lines
            [Array] $parts = ($_.Value -split '\r?\n').Trim()

            # Replace with string array if result is multiple lines
            if ($parts.Count -gt 1) {
                $_.Value = $parts
            }
        }

        # Convert single value array into string
        if ($_.Value -is [Array]) {
            # Array contains only 1 element String or Array
            if ($_.Value.Count -eq 1) {
                # Array
                if ($_.Value[0] -is [Array]) {
                    $_.Value = $_.Value
                } else {
                    # String
                    $_.Value = $_.Value[0]
                }
            } else {
                # Array of Arrays
                $resulted_arrs = @()
                foreach ($element in $_.Value) {
                    if ($element.Count -eq 1) {
                        $resulted_arrs += $element
                    } else {
                        $resulted_arrs += , $element
                    }
                }

                $_.Value = $resulted_arrs
            }
        }

        # Process other values as needed...
    }

    return $json
}
