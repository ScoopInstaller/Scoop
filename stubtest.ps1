$inv = $myinvocation

$name = $inv.InvocationName

[System.Management.Automation.Language.Token[]]$tokens = $null
[System.Management.Automation.Language.ScriptBlockAst]$ast =
    [System.Management.Automation.Language.Parser]::ParseInput($inv.line, [ref]$tokens, [ref]$null)

#$tokens | % { $_ }

$commands = $ast.FindAll({ ($args[0] -is [System.Management.Automation.Language.CommandAst]) -and ($args.getcommandname() -eq $name)}, $true)

$commands | % { $_.extent.text }
