
$inv = $myinvocation
#$inv

$name = $inv.InvocationName

$tokens = $null

$ast = [System.Management.Automation.Language.Parser]::ParseInput($inv.line, [ref]$tokens, [ref]$null)


$commands = $ast.FindAll({ ($args[0].gettype().name -eq 'commandast') -and ($args[0].invocationoperator -eq 'Ampersand')}, $true)

#$ast

#$tokens | where { $_.text -eq '&' } | % { $_.gettype() }

$commands | % { $_.extent.text }
