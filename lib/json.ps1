# Convert objects to pretty json
# Only needed until PowerShell ConvertTo-Json will be improved https://github.com/PowerShell/PowerShell/issues/2736
function ConvertToPrettyJson {
  [CmdletBinding()]

  param(
    [Parameter(Mandatory,ValueFromPipeline)]
    $data
  )

  process {
    [string]$json = $data | ConvertTo-Json -Depth 8 -Compress
    [string]$output = ""

    # state
    [string]$buffer = ""
    [int]$depth = 0
    [bool]$inString = $false

    # configuration
    [string]$indent = " " * 4
    [bool]$unescapeString = $true
    [string]$eol = "`r`n"

    for ($i = 0; $i -lt $json.length; $i++) {
      # read current char
      $buffer = $json.substring($i,1)

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
        $buffer = $json.substring($i,2)
        ++ $i

        # Unescape unicode
        if ($inString -and $unescapeString) {
          if ($buffer.Equals('\n')) {
            $buffer = "`n"
          } elseif ($buffer.Equals('\r')) {
            $buffer = "`r"
          } elseif ($buffer.Equals('\t')) {
            $buffer = "`t"
          } elseif ($buffer.Equals('\u')) {
            $buffer = [regex]::Unescape($json.substring($i - 1,6))
            $i += 4
          }
        }

        $output += $buffer
        continue
      }

      # indent / outdent
      if ($objectStart -or $arrayStart) {
        ++ $depth
      } elseif ($objectEnd -or $arrayEnd) {
        -- $depth
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

function json_path ([string]$json,[string]$jsonpath,[string]$basename) {
  Add-Type -Path "$psscriptroot\..\supporting\validator\Newtonsoft.Json.dll"
  $jsonpath = $jsonpath.Replace("`$basename",$basename)
  $obj = [Newtonsoft.Json.Linq.JObject]::Parse($json)
  $result = $null
  try {
    $result = $obj.SelectToken($jsonpath,$true)
  } catch [System.Management.Automation.MethodInvocationException]{
    Write-Host -f DarkRed $_
    return $null
  }
  return $result.ToString()
}

function json_path_legacy ([string]$json,[string]$jsonpath,[string]$basename) {
  $result = $json | ConvertFrom-Json -ea stop
  $isJsonPath = $jsonpath.StartsWith("`$")
  $jsonpath.Split(".") | ForEach-Object {
    $el = $_

    # substitute the base filename into the jsonpath
    if ($el.Contains("`$basename")) {
      $el = $el.Replace("`$basename",$basename)
    }

    # skip $ if it's jsonpath format
    if ($el -eq "`$" -and $isJsonPath) {
      return
    }

    # array detection
    if ($el -match "^(?<property>\w+)?\[(?<index>\d+)\]$") {
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
