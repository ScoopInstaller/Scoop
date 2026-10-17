function Get-DotSourceLiteralPath {
    # `$PSScriptRoot` is the only variable Scoop uses in dot-source paths.
    param(
        [System.Management.Automation.Language.CommandAst] $Command,
        [String] $File
    )

    $arg = $Command.CommandElements[0]
    $value = switch ($arg.GetType().Name) {
        'StringConstantExpressionAst' { $arg.Value }
        'ExpandableStringExpressionAst' { $arg.Value -replace '\$PSScriptRoot', (Split-Path $File -Parent) }
    }
    if (-not $value -or $value -match '\$') { return }
    if ([IO.Path]::IsPathRooted($value)) { [IO.Path]::GetFullPath($value) }
    # The process CWD is unknowable statically; the script's directory is the closest guess.
    else { [IO.Path]::GetFullPath((Join-Path (Split-Path $File -Parent) $value)) }
}

function Get-GetConfigConstraint {
    # Truth value implied by a `get_config X` guard, or $null when none; `-or` pins no single value.
    param([System.Management.Automation.Language.Ast] $Condition)

    if (-not $Condition) { return }
    $text = $Condition.Extent.Text
    if ($text -match '\s-or\s') { return }

    $name = [regex]::Match($text, 'get_config\s+([A-Za-z0-9_-]+)')
    if (-not $name.Success) { return }

    $negated = ($text -match '^\s*!') -or ($text -match '^\s*\(?\s*-not\b')
    @{ Key = $name.Groups[1].Value.ToLowerInvariant(); Value = (-not $negated) }
}

function Get-CommandConstraint {
    # Every `get_config X` guard the command sits behind, out to the enclosing ifs. An `elseif`
    # chain pins only its containing clause; `else` inverts each clause guard, dropping conflicts.
    param([System.Management.Automation.Language.CommandAst] $Command)

    $constraints = @{}
    $node = $Command.Parent
    while ($node) {
        # IfStatementAst.Clauses holds Tuple(condition, body) pairs, not clause objects.
        if ($node -is [System.Management.Automation.Language.IfStatementAst]) {
            $clause = $null
            foreach ($candidate in $node.Clauses) {
                $body = $candidate.Item2.Extent
                if ($Command.Extent.StartOffset -ge $body.StartOffset -and $Command.Extent.EndOffset -le $body.EndOffset) {
                    $clause = $candidate
                    break
                }
            }
            if ($clause) {
                $c = Get-GetConfigConstraint $clause.Item1
                if ($c) { $constraints[$c.Key] = $c.Value }
            } elseif ($node.ElseClause) {
                $else = $node.ElseClause.Extent
                if ($Command.Extent.StartOffset -ge $else.StartOffset -and $Command.Extent.EndOffset -le $else.EndOffset) {
                    $inverted = @{}
                    $dropped = @{}
                    foreach ($candidate in $node.Clauses) {
                        $c = Get-GetConfigConstraint $candidate.Item1
                        if (-not $c -or $dropped.ContainsKey($c.Key)) { continue }
                        $value = -not $c.Value
                        if ($inverted.ContainsKey($c.Key) -and $inverted[$c.Key] -ne $value) {
                            $inverted.Remove($c.Key)
                            $dropped[$c.Key] = $true
                        } else {
                            $inverted[$c.Key] = $value
                        }
                    }
                    foreach ($k in $inverted.Keys) { $constraints[$k] = $inverted[$k] }
                }
            }
        }
        $node = $node.Parent
    }
    $constraints
}

# shortcut: cached per Root and stale until the module is re-imported.
$script:indexCache = @{}

function Get-ScriptIndex {
    <#
    .SYNOPSIS
        Parses bin/, lib/, libexec/ and test/ once and records every call, definition and dot-source.
    .OUTPUTS
        Hashtable with files, defs, topStmts, topCmds, topDots, fnBodies, fnCmds, fnDots, fnKey,
        fnNested, fnAboveDots, cmdConstraints, invoked, hostSet and entries.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String] $Root
    )

    $Root = [IO.Path]::GetFullPath($Root)
    if ($script:indexCache.ContainsKey($Root)) { return $script:indexCache[$Root] }

    # test/ is indexed so reachability sees the suite's calls; it holds no entry points.
    $files = Get-ChildItem "$Root\bin", "$Root\lib", "$Root\libexec", "$Root\test" -Filter *.ps1 -Recurse |
        ForEach-Object FullName

    $defs = @{}          # name -> @{ File; Key; Owner; Stmt }[]
    $topStmts = @{}      # file -> top-level statements
    $topCmds = @{}       # file -> CommandAst[] per top-level statement
    $topDots = @{}       # file -> dot-sourced path[] per top-level statement
    $fnBodies = @{}      # Key -> FunctionDefinitionAst
    $fnCmds = @{}        # Key -> CommandAst[], nested bodies excluded
    $fnDots = @{}        # Key -> paths dot-sourced in the body
    $fnKey = @{}         # file -> name -> Key, nested defs get their own
    $invoked = @{}       # file -> hit through a literal `& path`
    $fnNested = @{}      # Key -> nested def keys, including itself
    $fnAboveDots = @{}   # Key -> paths dot-sourced above the def's statement
    $cmdConstraints = @{} # CommandAst -> constraints, filled on demand

    foreach ($file in $files) {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$null, [ref]$null)
        $stmts = @($ast.EndBlock.Statements)
        $topStmts[$file] = $stmts
        $topCmds[$file] = @()
        $topDots[$file] = @()
        $fnKey[$file] = @{}

        $bodies = [System.Collections.Generic.List[System.Management.Automation.Language.Ast]]::new()
        $commands = [System.Collections.Generic.List[System.Management.Automation.Language.CommandAst]]::new()
        foreach ($n in $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -or $x -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            if ($n -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $bodies.Add($n) } else { $commands.Add($n) }
        }
        $topFn = @{}
        for ($i = 0; $i -lt $stmts.Count; $i++) {
            $topCmds[$file] += , @()
            $topDots[$file] += , @()
            if ($stmts[$i] -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $topFn[$i] = $stmts[$i] }
        }

        $fileKeys = @()  # def keys in document order
        $fileStmts = @{} # key -> statement index
        for ($i = 0; $i -lt $bodies.Count; $i++) {
            $body = $bodies[$i]
            $key = '{0}#{1}' -f $file, $i
            $fnKey[$file][$body.Name] = $key
            $fnBodies[$key] = $body

            $ownerStmt = -1
            $ownerKey = ''
            for ($j = 0; $j -lt $stmts.Count; $j++) {
                if ($body.Extent.StartOffset -lt $stmts[$j].Extent.StartOffset -or $body.Extent.EndOffset -gt $stmts[$j].Extent.EndOffset) { continue }
                $ownerStmt = $j
                if ($topFn.ContainsKey($j) -and $topFn[$j] -ne $body) { $ownerKey = $fnKey[$file][$topFn[$j].Name] }
            }
            $fileKeys += $key
            $fileStmts[$key] = $ownerStmt
            if (-not $defs.ContainsKey($body.Name)) { $defs[$body.Name] = @() }
            $defs[$body.Name] += , @{ File = $file; Key = $key; Owner = $ownerKey; Stmt = $ownerStmt }
        }

        # Bodies are in document order, so a reverse scan finds the innermost containing body first.
        $bodyRanges = [Object[]]::new($bodies.Count)
        for ($i = 0; $i -lt $bodies.Count; $i++) {
            $bodyRanges[$i] = @{
                Start = $bodies[$i].Body.Extent.StartOffset
                End   = $bodies[$i].Body.Extent.EndOffset
                Key   = $fnKey[$file][$bodies[$i].Name]
            }
        }
        $stmtRanges = [Object[]]::new($stmts.Count)
        for ($i = 0; $i -lt $stmts.Count; $i++) {
            $stmtRanges[$i] = @{
                Start = $stmts[$i].Extent.StartOffset
                End   = $stmts[$i].Extent.EndOffset
            }
        }

        foreach ($cmd in $commands) {
            $start = $cmd.Extent.StartOffset
            $end = $cmd.Extent.EndOffset
            $owner = ''
            for ($i = $bodyRanges.Count - 1; $i -ge 0; $i--) {
                if ($start -ge $bodyRanges[$i].Start -and $end -le $bodyRanges[$i].End) { $owner = $bodyRanges[$i].Key; break }
            }

            # `.` and `&` never appear in CommandElements; the parent PipelineAst says which it is.
            if (-not $cmd.GetCommandName()) {
                $operator = $cmd.Parent.Extent.Text.TrimStart().Substring(0, 1)
                $target = Get-DotSourceLiteralPath $cmd $file
                if ($operator -eq '&' -and $target) { $invoked[$target] = $true }
                if ($target) {
                    if ($owner) {
                        if (-not $fnDots.ContainsKey($owner)) { $fnDots[$owner] = @() }
                        $fnDots[$owner] += , $target
                    } else {
                        for ($i = 0; $i -lt $stmtRanges.Count; $i++) {
                            if ($start -ge $stmtRanges[$i].Start -and $end -le $stmtRanges[$i].End) { $topDots[$file][$i] += , $target; break }
                        }
                    }
                }
                continue
            }

            if ($owner) {
                if (-not $fnCmds.ContainsKey($owner)) { $fnCmds[$owner] = @() }
                $fnCmds[$owner] += , $cmd
            } else {
                for ($i = 0; $i -lt $stmtRanges.Count; $i++) {
                    if ($start -ge $stmtRanges[$i].Start -and $end -le $stmtRanges[$i].End) { $topCmds[$file][$i] += , $cmd; break }
                }
            }
        }

        # Per-definition data computed once; the nested set uses the fnKey view so duplicate names match.
        $namedKeys = @($fnKey[$file].Values)
        $namedExtents = [Object[]]::new($namedKeys.Count)
        for ($i = 0; $i -lt $namedKeys.Count; $i++) {
            $namedExtents[$i] = $fnBodies[$namedKeys[$i]].Body.Extent
        }
        foreach ($key in $fileKeys) {
            $scope = $fnBodies[$key].Body.Extent
            $inner = @()
            for ($i = 0; $i -lt $namedKeys.Count; $i++) {
                if ($namedExtents[$i].StartOffset -ge $scope.StartOffset -and $namedExtents[$i].EndOffset -le $scope.EndOffset) { $inner += $namedKeys[$i] }
            }
            $fnNested[$key] = $inner

            $above = @()
            for ($j = 0; $j -lt $fileStmts[$key]; $j++) { foreach ($t in $topDots[$file][$j]) { if ($t) { $above += $t } } }
            $fnAboveDots[$key] = $above
        }
    }

    # Everything bin/scoop.ps1 puts into the session of the libexec script it dispatches to.
    $hostSet = @{}
    $hostQueue = [System.Collections.Generic.Queue[String]]::new()
    $hostQueue.Enqueue((Join-Path $Root 'bin\scoop.ps1'))
    while ($hostQueue.Count) {
        $current = $hostQueue.Dequeue()
        if (-not $current -or $hostSet.ContainsKey($current) -or -not $topStmts.ContainsKey($current)) { continue }
        $hostSet[$current] = $true
        foreach ($list in $topDots[$current]) { foreach ($t in $list) { if ($t) { $hostQueue.Enqueue($t) } } }
        foreach ($k in $fnKey[$current].Values) { foreach ($t in $fnDots[$k]) { $hostQueue.Enqueue($t) } }
    }

    $entries = @()
    $entries += Get-ChildItem "$Root\bin" -Filter *.ps1 | ForEach-Object FullName
    $entries += Get-ChildItem "$Root\libexec" -Filter *.ps1 | ForEach-Object FullName
    $entries = $entries | Where-Object { -not ($invoked.ContainsKey($_) -and $_ -like "$Root\bin\*") }

    $result = @{
        files = $files; defs = $defs; topStmts = $topStmts; topCmds = $topCmds; topDots = $topDots
        fnBodies = $fnBodies; fnCmds = $fnCmds; fnDots = $fnDots; fnKey = $fnKey
        fnNested = $fnNested; fnAboveDots = $fnAboveDots; cmdConstraints = $cmdConstraints
        invoked = $invoked; hostSet = $hostSet; entries = $entries
    }
    $script:indexCache[$Root] = $result
    $result
}

function Get-DotSourceIssue {
    <#
    .SYNOPSIS
        Finds functions a script calls but cannot see when it runs.
    .DESCRIPTION
        Scoop dot-sources lib/*.ps1 as plain scripts, so a function can exist in the repository and
        still be undefined at the call site. Both shapes need the whole call path, not just the
        script: a file the entry point never loads (bin/auto-pr.ps1 -> lib/manifest.ps1 -> warn), and
        a file it loads too late (function execute at line 106 calls abort, lib/core.ps1 only arrives
        at line 176). #6514, #6747 and #6786 were all that shape.

        Entry points are bin/*.ps1 (run directly) and libexec/*.ps1 (dispatched through `exec`, so
        they inherit whatever bin/scoop.ps1 loaded). lib/*.ps1 are never entry points. A bin script
        reached only through a literal `& path` runs inside its caller's session.

        Only repository-defined names are checked, so cmdlets, executables and `&$var` need no
        allowlist. Branches whose `get_config` guards contradict each other are never followed,
        only functions that are actually invoked are inspected, and calls inside a nested
        function body are checked with the visibility of the call site that entered its owner.
    .OUTPUTS
        One object per unresolved call: Path, Entry, Chain, Line, Name, DefinedIn.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String] $Root
    )

    $index = Get-ScriptIndex -Root $Root
    $defs = $index.defs
    $topStmts = $index.topStmts
    $topCmds = $index.topCmds
    $topDots = $index.topDots
    $fnCmds = $index.fnCmds
    $fnDots = $index.fnDots
    $fnNested = $index.fnNested
    $fnAboveDots = $index.fnAboveDots
    $cmdConstraints = $index.cmdConstraints
    $hostSet = $index.hostSet
    $entries = $index.entries

    $issues = @()
    foreach ($entry in $entries) {
        $inherits = $entry -like "$Root\libexec\*"

        # A function loads files when it runs (lib/core.ps1 does this lazily): treat every file
        # reachable from this entry as available. Top-level dot-sources stay order-sensitive below.
        $lazy = @{}
        $seen = @{}
        $names = [System.Collections.Generic.Queue[String]]::new()
        foreach ($list in $topCmds[$entry]) { foreach ($c in $list) { $names.Enqueue($c.GetCommandName()) } }
        while ($names.Count) {
            $name = $names.Dequeue()
            if (-not $name -or $seen.ContainsKey($name) -or -not $defs.ContainsKey($name)) { continue }
            $seen[$name] = $true
            foreach ($d in $defs[$name]) {
                foreach ($k in $fnNested[$d.Key]) {
                    foreach ($t in $fnDots[$k]) { if ($t) { $lazy[$t] = $true } }
                    foreach ($c in $fnCmds[$k]) { $names.Enqueue($c.GetCommandName()) }
                }
            }
        }

        $loaded = @{ $entry = $true }
        foreach ($t in $lazy.Keys) { $loaded[$t] = $true }
        $visited = @{}
        $queue = [System.Collections.Generic.Queue[Object]]::new()

        # Top level runs in source order: a dot-source below a call cannot satisfy it.
        for ($i = 0; $i -lt $topStmts[$entry].Count; $i++) {
            foreach ($t in $topDots[$entry][$i]) { if ($t) { $loaded[$t] = $true } }
            if ($topCmds[$entry][$i].Count) {
                $queue.Enqueue(@{ File = $entry; Calls = $topCmds[$entry][$i]; Loaded = $loaded.Clone(); Fns = @{}; Env = @{}; Chain = @((Split-Path $entry -Leaf)) })
            }
        }

        while ($queue.Count) {
            $item = $queue.Dequeue()
            foreach ($call in $item.Calls) {
                $name = $call.GetCommandName()
                if (-not $name -or -not $defs.ContainsKey($name)) { continue }

                # Drop branches whose get_config guards contradict an enclosing one.
                if (-not $cmdConstraints.ContainsKey($call)) { $cmdConstraints[$call] = Get-CommandConstraint $call }
                $constraints = $cmdConstraints[$call]
                $env = $item.Env
                if ($constraints -and $constraints.Count) {
                    $env = $item.Env.Clone()
                    $skip = $false
                    foreach ($c in $constraints.Keys) {
                        if (-not $env.ContainsKey($c)) { $env[$c] = $constraints[$c] }
                        elseif ($env[$c] -ne $constraints[$c]) { $skip = $true }
                    }
                    if ($skip) { continue }
                }

                $visible = $false
                foreach ($d in $defs[$name]) {
                    if (-not ($item.Loaded.ContainsKey($d.File) -or ($inherits -and $hostSet.ContainsKey($d.File)))) { continue }
                    if ($d.Owner -and -not $item.Fns.ContainsKey($d.Owner)) { continue }
                    $visible = $true
                    break
                }
                if (-not $visible) {
                    $issues += [PSCustomObject]@{
                        Path      = $item.File
                        Entry     = Split-Path $entry -Leaf
                        Chain     = $item.Chain
                        Line      = $call.Extent.StartLineNumber
                        Name      = $name
                        DefinedIn = ($defs[$name] | ForEach-Object { Split-Path $_.File -Leaf }) -join ','
                    }
                    continue
                }

                foreach ($d in $defs[$name]) {
                    if ($visited.ContainsKey($d.Key)) { continue }
                    $visited[$d.Key] = $true

                    $child = $item.Loaded.Clone()
                    $child[$d.File] = $true
                    foreach ($t in $fnAboveDots[$d.Key]) { $child[$t] = $true }
                    foreach ($t in $fnDots[$d.Key]) { if ($t) { $child[$t] = $true } }

                    $fns = $item.Fns.Clone()
                    foreach ($k in $fnNested[$d.Key]) { $fns[$k] = $true }
                    $fns[$d.Key] = $true

                    $chain = $item.Chain + "$name()"
                    $queue.Enqueue(@{
                        File = $d.File; Calls = $fnCmds[$d.Key]; Loaded = $child
                        Fns = $fns; Env = $env; Chain = $chain
                    })

                    # A nested function body runs in its owner's session, so its calls get the same state.
                    foreach ($k in $fnNested[$d.Key]) {
                        if ($visited.ContainsKey($k)) { continue }
                        $visited[$k] = $true
                        $queue.Enqueue(@{
                            File = $d.File; Calls = $fnCmds[$k]; Loaded = $child
                            Fns = $fns; Env = $env; Chain = $chain
                        })
                    }
                }
            }
        }
    }
    $issues
}

Export-ModuleMember -Function Get-DotSourceIssue
