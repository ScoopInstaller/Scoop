# Convert objects to pretty json
# Only needed until PowerShell ConvertTo-Json will be improved https://github.com/PowerShell/PowerShell/issues/2736
Function ConvertToPrettyJson {
    [cmdletbinding()]

    Param (
        [parameter(Mandatory, ValueFromPipeline)]
        $data
    )

    Process  {
        [String]$json = $data | ConvertTo-Json -Depth 8 -Compress
        [String]$output = ""

        # state
        [String]$buffer = ""
        [Int]$depth = 0
        [Bool]$inString = $false

        # configuration
        [String]$indent = " " * 4
        [Bool]$unescapeString = $true
        [String]$eol = "`r`n"

        for ($i = 0; $i -lt $json.Length; $i++) {
            # read current char
            $buffer = $json.Substring($i, 1)

            #
            $objectStart = !$inString -and $buffer.Equals("{")
            $objectEnd = !$inString -and $buffer.Equals("}")
            $arrayStart = !$inString -and $buffer.Equals("[")
            $arrayEnd = !$inString -and $buffer.Equals("]")
            $colon = !$inString -and $buffer.Equals(":")
            $comma = !$inString -and $buffer.Equals(",")
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
                $output += " "
            } elseif ($comma -or $arrayStart -or $objectStart) {
                $output += $eol
                $output += $indent * $depth
            }
        }

        $output
    }
}

function json_path([Object] $json, [String] $jsonpath, [String] $basename) {
    $result = $json
    $isJsonPath = $jsonpath.StartsWith("`$")
    $jsonpath.split(".") | ForEach-Object {
        $el = $_

        # substitute the base filename into the jsonpath
        if($el.StartsWith("`$basename")) {
            $el = $el.Replace("`$basename", $basename)
        }

        # skip $ if it's jsonpath format
        if($el -eq "`$" -and $isJsonPath) {
            return
        }

        if($el -match "^(?<property>\w+)\[(?<index>\d+)\]$") {
            $property = $matches['property']
            $result = $result.$property[$matches['index']]
            return
        }

        $result = $result.$el
    }
    return $result
}
