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

function Get-BodyStmtIndex {
    param($FnStmtRanges, [String] $Key, [Int] $Start, [Int] $End)

    $ranges = $FnStmtRanges[$Key]
    for ($j = 0; $j -lt $ranges.Count; $j++) {
        if ($Start -ge $ranges[$j].Start -and $End -le $ranges[$j].End) { return $j }
    }
    0
}

function Get-GetConfigConstraint {
    # Truth value implied by a `get_config X` guard, or $null when none: `-or` pins no single
    # value, a comparison chained onto the call is about the value, and an operator further out,
    # like `-and ($app -ne 'scoop')`, says nothing about the config.
    param([System.Management.Automation.Language.Ast] $Condition)

    if (-not $Condition) { return }
    $text = $Condition.Extent.Text
    if ($text -match '\s-or\s') { return }

    $name = [regex]::Match($text, 'get_config\s+([A-Za-z0-9_-]+)')
    if (-not $name.Success) { return }
    $rest = $text.Substring($name.Index + $name.Length)
    if ($rest -match '^(?:\s+(?:''[^'']*''|\$\w+))?(?:\s*\))+\s*-(?:eq|ne|ieq|ine|ge|gt|le|lt|like|notlike|match|notmatch|in|notin|contains|is|isnot|band|bor)\b') { return }

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
                        # Only a guard that stands alone can be inverted: in `A -and B` the else
                        # branch also runs when A holds and B does not.
                        if ($candidate.Item1.Extent.Text -match '-(and|or)\b') { continue }
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
        Hashtable with root, files, defs, topStmts, topCmds, topDots, fnBodies, fnCmds, fnDots,
        fnFileKeys, fnNested, fnAboveDots, cmdConstraints, asts, invoked, hostSet and entries.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String] $Root
    )

    # Canonical cache key and -like base: a relative, `..`-containing or trailing-separator
    # Root would never match the absolute paths recorded below.
    $Root = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    if ($script:indexCache.ContainsKey($Root)) { return $script:indexCache[$Root] }

    # test/ is indexed so reachability sees the suite's calls; it holds no entry points.
    $files = Get-ChildItem "$Root\bin", "$Root\lib", "$Root\libexec", "$Root\test" -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object FullName

    $defs = @{}          # name -> @{ File; Key; Owner; Stmt }[]
    $topStmts = @{}      # file -> top-level statements
    $topCmds = @{}       # file -> CommandAst[] per top-level statement
    $topDots = @{}       # file -> dot-sourced path[] per top-level statement
    $topRuns = @{}       # file -> `& path` target[] per top-level statement
    $fnBodies = @{}      # Key -> FunctionDefinitionAst
    $fnCmds = @{}        # Key -> CommandAst[], nested bodies excluded
    $fnDots = @{}        # Key -> paths dot-sourced in the body
    $fnRuns = @{}        # Key -> `& path` targets run in the body
    $fnStmts = @{}       # Key -> body statement count
    $fnStmtRanges = @{}  # Key -> body statement offsets
    $fnStmtCmds = @{}    # Key -> CommandAst[] per body statement
    $fnStmtDots = @{}    # Key -> path[] per body statement
    $fnStmtRuns = @{}    # Key -> `& path` target[] per body statement
    $fnFileKeys = @{}    # file -> every def Key, same-name defs included
    $invoked = @{}       # file -> hit through a literal `& path`
    $asts = @{}          # file -> AST for the string-literal pass
    $fnNested = @{}      # Key -> nested def keys, including itself
    $fnAboveDots = @{}   # Key -> paths dot-sourced above the def's statement
    $cmdConstraints = @{} # CommandAst -> constraints, filled on demand

    foreach ($file in $files) {
        $tokens = $null
        $parseErrors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors) {
            Write-Warning ("{0}: {1} parse error(s); analysis of this file may be incomplete" -f $file, $parseErrors.Count)
        }
        $asts[$file] = $ast
        $stmts = @($ast.EndBlock.Statements)
        $topStmts[$file] = $stmts
        $topCmds[$file] = @()
        $topDots[$file] = @()

        $bodies = [System.Collections.Generic.List[System.Management.Automation.Language.Ast]]::new()
        $commands = [System.Collections.Generic.List[System.Management.Automation.Language.CommandAst]]::new()
        foreach ($n in $ast.FindAll({ param($x) $x -is [System.Management.Automation.Language.FunctionDefinitionAst] -or $x -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            if ($n -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $bodies.Add($n) } else { $commands.Add($n) }
        }
        $topFn = @{}
        for ($i = 0; $i -lt $stmts.Count; $i++) {
            $topCmds[$file] += , @()
            $topDots[$file] += , @()
            $topRuns[$file] += , @()
            if ($stmts[$i] -is [System.Management.Automation.Language.FunctionDefinitionAst]) { $topFn[$i] = $stmts[$i] }
        }

        $fileKeys = @()  # def keys in document order
        $fileStmts = @{} # key -> statement index
        $keyOf = @{}     # FunctionDefinitionAst -> its own key, same-name defs apart
        for ($i = 0; $i -lt $bodies.Count; $i++) {
            $body = $bodies[$i]
            $key = '{0}#{1}' -f $file, $i
            $keyOf[$body] = $key
            $fnBodies[$key] = $body

            # Per body statement, so the walk can apply dot-sources in the order they run.
            $bodyStmts = @($body.Body.EndBlock.Statements)
            $fnStmts[$key] = $bodyStmts.Count
            $ranges = [Object[]]::new($bodyStmts.Count)
            $cmdGrid = [Object[]]::new($bodyStmts.Count)
            $dotGrid = [Object[]]::new($bodyStmts.Count)
            $runGrid = [Object[]]::new($bodyStmts.Count)
            for ($j = 0; $j -lt $bodyStmts.Count; $j++) {
                $ranges[$j] = @{ Start = $bodyStmts[$j].Extent.StartOffset; End = $bodyStmts[$j].Extent.EndOffset }
                $cmdGrid[$j] = [System.Collections.Generic.List[Object]]::new()
                $dotGrid[$j] = [System.Collections.Generic.List[Object]]::new()
                $runGrid[$j] = [System.Collections.Generic.List[Object]]::new()
            }
            $fnStmtRanges[$key] = $ranges
            $fnStmtCmds[$key] = $cmdGrid
            $fnStmtDots[$key] = $dotGrid
            $fnStmtRuns[$key] = $runGrid

            $ownerStmt = -1
            $ownerKey = ''
            for ($j = 0; $j -lt $stmts.Count; $j++) {
                if ($body.Extent.StartOffset -lt $stmts[$j].Extent.StartOffset -or $body.Extent.EndOffset -gt $stmts[$j].Extent.EndOffset) { continue }
                $ownerStmt = $j
                if ($topFn.ContainsKey($j) -and $topFn[$j] -ne $body) { $ownerKey = $keyOf[$topFn[$j]] }
            }
            $fileKeys += $key
            $fileStmts[$key] = $ownerStmt
            if (-not $defs.ContainsKey($body.Name)) { $defs[$body.Name] = @() }
            $defs[$body.Name] += , @{ File = $file; Key = $key; Owner = $ownerKey; Stmt = $ownerStmt }
        }
        $fnFileKeys[$file] = $fileKeys

        # Bodies are in document order, so a reverse scan finds the innermost containing body first.
        $bodyRanges = [Object[]]::new($bodies.Count)
        for ($i = 0; $i -lt $bodies.Count; $i++) {
            $bodyRanges[$i] = @{
                Start = $bodies[$i].Body.Extent.StartOffset
                End   = $bodies[$i].Body.Extent.EndOffset
                Key   = $keyOf[$bodies[$i]]
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

            if (-not $cmd.GetCommandName()) {
                $invocation = "$($cmd.InvocationOperator)"
                $target = Get-DotSourceLiteralPath $cmd $file
                if ($invocation -eq 'Ampersand') {
                    if (-not $target) { continue }
                    $invoked[$target] = $true
                    if ($owner) {
                        if (-not $fnRuns.ContainsKey($owner)) { $fnRuns[$owner] = @() }
                        $fnRuns[$owner] += , $target
                        $fnStmtRuns[$owner][(Get-BodyStmtIndex $fnStmtRanges $owner $start $end)].Add($target)
                    } else {
                        for ($i = 0; $i -lt $stmtRanges.Count; $i++) {
                            if ($start -ge $stmtRanges[$i].Start -and $end -le $stmtRanges[$i].End) { $topRuns[$file][$i] += , $target; break }
                        }
                    }
                    continue
                }
                if ($target) {
                    if ($owner) {
                        if (-not $fnDots.ContainsKey($owner)) { $fnDots[$owner] = @() }
                        $fnDots[$owner] += , $target
                        $fnStmtDots[$owner][(Get-BodyStmtIndex $fnStmtRanges $owner $start $end)].Add($target)
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
                $fnStmtCmds[$owner][(Get-BodyStmtIndex $fnStmtRanges $owner $start $end)].Add($cmd)
            } else {
                for ($i = 0; $i -lt $stmtRanges.Count; $i++) {
                    if ($start -ge $stmtRanges[$i].Start -and $end -le $stmtRanges[$i].End) { $topCmds[$file][$i] += , $cmd; break }
                }
            }
        }

        # Per-definition data computed once; $fileKeys keeps same-name defs apart.
        $namedExtents = [Object[]]::new($fileKeys.Count)
        for ($i = 0; $i -lt $fileKeys.Count; $i++) {
            $namedExtents[$i] = $fnBodies[$fileKeys[$i]].Body.Extent
        }
        foreach ($key in $fileKeys) {
            $scope = $fnBodies[$key].Body.Extent
            $inner = @()
            for ($i = 0; $i -lt $fileKeys.Count; $i++) {
                if ($namedExtents[$i].StartOffset -ge $scope.StartOffset -and $namedExtents[$i].EndOffset -le $scope.EndOffset) { $inner += $fileKeys[$i] }
            }
            $fnNested[$key] = $inner

            $above = @()
            for ($j = 0; $j -lt $fileStmts[$key]; $j++) { foreach ($t in $topDots[$file][$j]) { if ($t) { $above += $t } } }
            $fnAboveDots[$key] = $above
        }
    }

    # A dot-sourced script runs its whole body, so the files it pulls in are loaded with it.
    $dotClosure = @{}
    $dotQueue = [System.Collections.Generic.Queue[String]]::new()
    foreach ($file in $files) { $dotQueue.Enqueue($file) }
    while ($dotQueue.Count) {
        $current = $dotQueue.Dequeue()
        if (-not $current -or $dotClosure.ContainsKey($current)) { continue }
        $targets = @{}
        foreach ($list in $topDots[$current]) { foreach ($t in $list) { if ($t) { $targets[$t] = $true } } }
        $dotClosure[$current] = @($targets.Keys)
        foreach ($t in $targets.Keys) { $dotQueue.Enqueue($t) }
    }
    foreach ($key in @($fnDots.Keys)) {
        $expanded = @{}
        foreach ($t in $fnDots[$key]) { $expanded[$t] = $true; foreach ($c in $dotClosure[$t]) { $expanded[$c] = $true } }
        $fnDots[$key] = @($expanded.Keys)
    }
    foreach ($key in @($fnAboveDots.Keys)) {
        $expanded = @{}
        foreach ($t in $fnAboveDots[$key]) { $expanded[$t] = $true; foreach ($c in $dotClosure[$t]) { $expanded[$c] = $true } }
        $fnAboveDots[$key] = @($expanded.Keys)
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
        foreach ($k in $fnFileKeys[$current]) { foreach ($t in $fnDots[$k]) { $hostQueue.Enqueue($t) } }
    }

    $entries = @()
    $entries += Get-ChildItem "$Root\bin" -Filter *.ps1 | ForEach-Object FullName
    $entries += Get-ChildItem "$Root\libexec" -Filter *.ps1 | ForEach-Object FullName
    $entries = $entries | Where-Object { -not ($invoked.ContainsKey($_) -and $_ -like "$Root\bin\*") }

    $result = @{
        root = $Root
        files = $files; defs = $defs; topStmts = $topStmts; topCmds = $topCmds; topDots = $topDots; topRuns = $topRuns
        fnBodies = $fnBodies; fnCmds = $fnCmds; fnDots = $fnDots; fnRuns = $fnRuns; fnFileKeys = $fnFileKeys
        fnStmts = $fnStmts; fnStmtCmds = $fnStmtCmds; fnStmtDots = $fnStmtDots; fnStmtRuns = $fnStmtRuns
        fnNested = $fnNested; fnAboveDots = $fnAboveDots; cmdConstraints = $cmdConstraints
        invoked = $invoked; hostSet = $hostSet; entries = $entries; asts = $asts; dotClosure = $dotClosure
    }
    $script:indexCache[$Root] = $result
    $result
}

function Add-TopLevelWalk {
    # A dot-source below a call cannot satisfy it; an `& path` target keeps its caller's files and
    # sees only the definitions that ran before the call, recorded in Limits.
    param($Index, [String] $File, $Loaded, $Fns, $Env, [String] $EnvKey, $Chain, $Queue, $Seen, $Limits)

    if ($Seen.ContainsKey($File) -or -not $Index.topStmts.ContainsKey($File)) { return }
    $Seen[$File] = $true
    $loaded = $Loaded.Clone()
    $loaded[$File] = $true
    for ($i = 0; $i -lt $Index.topStmts[$File].Count; $i++) {
        foreach ($t in $Index.topDots[$File][$i]) {
            if (-not $t) { continue }
            $loaded[$t] = $true
            foreach ($c in $Index.dotClosure[$t]) { $loaded[$c] = $true }
            # A dot-sourced script runs its whole body here, in this session's current state.
            Add-TopLevelWalk -Index $Index -File $t -Loaded $loaded -Fns $Fns -Env $Env `
                -EnvKey $EnvKey -Chain $Chain -Queue $Queue -Seen $Seen -Limits $Limits
        }
        if ($Index.topCmds[$File][$i].Count) {
            $Queue.Enqueue(@{
                File = $File; Stmt = $i; Calls = $Index.topCmds[$File][$i]
                Loaded = $loaded.Clone(); Fns = $Fns; Env = $Env; EnvKey = $EnvKey
                Chain = $Chain; Limits = $Limits
            })
        }
        foreach ($r in $Index.topRuns[$File][$i]) {
            # An entry is walked on its own terms, and a libexec one sees more than this call site.
            if ($Index.entries -contains $r) { continue }
            $nextLimits = @($Limits | Where-Object { $_ })
            $nextLimits += @{ File = $File; Stmt = $i }
            Add-TopLevelWalk -Index $Index -File $r -Loaded $loaded -Fns $Fns -Env $Env `
                -EnvKey $EnvKey -Chain $Chain -Queue $queue -Seen $Seen -Limits $nextLimits
        }
    }
    # Only cycles are cut: two call sites of one script each carry their own loaded set.
    $Seen.Remove($File)
}

function Add-BodyWalk {
    # A body runs its statements in order, so a dot-source below a call cannot satisfy it.
    param($Index, [String] $Key, [String] $File, $Loaded, $Fns, $Env, [String] $EnvKey, $Chain, $Queue, $Limits)

    $loaded = $Loaded.Clone()
    for ($j = 0; $j -lt $Index.fnStmts[$Key]; $j++) {
        foreach ($t in $Index.fnStmtDots[$Key][$j]) {
            if (-not $t) { continue }
            $loaded[$t] = $true
            foreach ($c in $Index.dotClosure[$t]) { $loaded[$c] = $true }
            Add-TopLevelWalk -Index $Index -File $t -Loaded $loaded -Fns $Fns -Env $Env `
                -EnvKey $EnvKey -Chain $Chain -Queue $Queue -Seen @{} -Limits $Limits
        }
        if ($Index.fnStmtCmds[$Key][$j].Count) {
            $Queue.Enqueue(@{
                File = $File; Calls = $Index.fnStmtCmds[$Key][$j]
                Loaded = $loaded.Clone(); Fns = $Fns; Env = $Env; EnvKey = $EnvKey
                Chain = $Chain; Limits = $Limits
            })
        }
        foreach ($r in $Index.fnStmtRuns[$Key][$j]) {
            if ($Index.entries -contains $r) { continue }
            Add-TopLevelWalk -Index $Index -File $r -Loaded $loaded -Fns $Fns -Env $Env `
                -EnvKey $EnvKey -Chain $Chain -Queue $Queue -Seen @{} -Limits $Limits
        }
    }
}

function Get-DotSourceIssue {
    <#
    .SYNOPSIS
        Finds functions a script calls but cannot see when it runs.
    .DESCRIPTION
        Scoop dot-sources lib/*.ps1 as plain scripts, so a function can exist in the repository
        and still be undefined at the call site: a file the entry point never loads, or loads
        after the call. Entry points are bin/*.ps1 and libexec/*.ps1 (the latter inheriting
        bin/scoop.ps1's dot-sources); contradictory `get_config` branches are skipped and
        nested bodies are checked with their owner's visibility.
    .OUTPUTS
        One object per unresolved call: Path, Entry, Chain, Line, Name, DefinedIn.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String] $Root
    )

    $index = Get-ScriptIndex -Root $Root
    $Root = $index.root
    $defs = $index.defs
    $topCmds = $index.topCmds
    $fnCmds = $index.fnCmds
    $fnDots = $index.fnDots
    $fnRuns = $index.fnRuns
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
        foreach ($t in $lazy.Keys) {
            $loaded[$t] = $true
            foreach ($c in $index.dotClosure[$t]) { $loaded[$c] = $true }
        }
        $visited = @{}
        $queue = [System.Collections.Generic.Queue[Object]]::new()
        Add-TopLevelWalk -Index $index -File $entry -Loaded $loaded -Fns @{} -Env @{} -EnvKey '' `
            -Chain @((Split-Path $entry -Leaf)) -Queue $queue -Seen @{}

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
                    # Top-level statements run in order: an entry-file definition below the
                    # calling statement has not run yet when the call executes.
                    if ($null -ne $item.Stmt -and $d.File -eq $item.File -and $d.Stmt -gt $item.Stmt) { continue }
                    # Same for a caller's definitions seen by a script it invoked.
                    $limited = $false
                    if ($item.Limits) {
                        foreach ($l in $item.Limits) {
                            if ($d.File -eq $l.File -and $d.Stmt -gt $l.Stmt) { $limited = $true; break }
                        }
                    }
                    if ($limited) { continue }
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

                $envKey = ''
                if ($env.Count) {
                    $keys = @($env.Keys)
                    [Array]::Sort($keys)
                    $envKey = ($keys | ForEach-Object { "$_=$($env[$_])" }) -join ','
                }
                $callLimits = @()
                if ($null -ne $item.Limits) { $callLimits = @($item.Limits) }
                if ($null -ne $item.Stmt) { $callLimits += @{ File = $item.File; Stmt = $item.Stmt } }
                foreach ($d in $defs[$name]) {
                    $visitKey = "$($d.Key)|$envKey"
                    if ($visited.ContainsKey($visitKey)) { continue }
                    $visited[$visitKey] = $true

                    $child = $item.Loaded.Clone()
                    $child[$d.File] = $true
                    if ($d.File -ne $entry) {
                        foreach ($c in $index.dotClosure[$d.File]) { $child[$c] = $true }
                    }
                    foreach ($t in $fnAboveDots[$d.Key]) { $child[$t] = $true }

                    $fns = $item.Fns.Clone()
                    foreach ($k in $fnNested[$d.Key]) { $fns[$k] = $true }
                    $fns[$d.Key] = $true

                    $chain = $item.Chain + "$name()"
                    Add-BodyWalk -Index $index -Key $d.Key -File $d.File -Loaded $child -Fns $fns -Env $env `
                        -EnvKey $envKey -Chain $chain -Queue $queue -Limits $callLimits

                    # A nested body called by name is walked precisely at its call statement; one
                    # reached only through a variable (`& $handler`) has no call site to walk from.
                    $ownerCalls = @{}
                    foreach ($list in $index.fnStmtCmds[$d.Key]) {
                        foreach ($c in $list) { $n = $c.GetCommandName(); if ($n) { $ownerCalls[$n] = $true } }
                    }
                    foreach ($k in $fnNested[$d.Key]) {
                        if ($ownerCalls.ContainsKey($index.fnBodies[$k].Name)) { continue }
                        $nestedKey = "$k|$envKey"
                        if ($visited.ContainsKey($nestedKey)) { continue }
                        $visited[$nestedKey] = $true
                        Add-BodyWalk -Index $index -Key $k -File $d.File -Loaded $child -Fns $fns -Env $env `
                            -EnvKey $envKey -Chain $chain -Queue $queue -Limits $callLimits
                    }
                }
            }
        }
    }
    $issues
}

function Get-Deprecation {
    param([System.Management.Automation.Language.FunctionDefinitionAst] $Body)

    $text = $Body.Extent.Text
    if ($text -match 'Show-DeprecatedWarning\s+\$MyInvocation\s+''([^'']+)''') {
        @{ Deprecated = $true; ReplacedBy = $Matches[1] }
    } elseif ($text -match 'is deprecated') {
        @{ Deprecated = $true; ReplacedBy = '' }
    } else {
        @{ Deprecated = $false; ReplacedBy = '' }
    }
}

function Get-StringReachedNames {
    # Names the code hands to `& $var` rather than calling directly, including wildcard
    # strings searched as text. Command names, member names and hashtable keys are syntax
    # rather than data, so their extents are skipped.
    param($Index, $Defs)

    $names = @{}
    foreach ($file in $Index.files) {
        $syntaxStart = @{}
        $strings = [System.Collections.Generic.List[System.Management.Automation.Language.Ast]]::new()
        foreach ($n in $Index.asts[$file].FindAll({
                param($x) $x -is [System.Management.Automation.Language.CommandAst] -or
                $x -is [System.Management.Automation.Language.MemberExpressionAst] -or
                $x -is [System.Management.Automation.Language.HashtableAst] -or
                $x -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                $x -is [System.Management.Automation.Language.ExpandableStringExpressionAst]
            }, $true)) {
            if ($n -is [System.Management.Automation.Language.StringConstantExpressionAst] -or $n -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
                $strings.Add($n)
            } elseif ($n -is [System.Management.Automation.Language.CommandAst]) {
                if ($n.GetCommandName()) { $syntaxStart[$n.CommandElements[0].Extent.StartOffset] = $true }
            } elseif ($n -is [System.Management.Automation.Language.MemberExpressionAst]) {
                $syntaxStart[$n.Member.Extent.StartOffset] = $true
            } else {
                foreach ($pair in $n.KeyValuePairs) { $syntaxStart[$pair.Item1.Extent.StartOffset] = $true }
            }
        }

        foreach ($s in $strings) {
            if ($syntaxStart.ContainsKey($s.Extent.StartOffset)) { continue }
            $value = $s.Value.Trim()
            if (-not $value) { continue }
            if ($Defs.ContainsKey($value)) {
                $names[$value] = $true
                continue
            }
            if ($value -notmatch '[\*\?]') { continue }
            foreach ($segment in ($value -split '[\*\?]')) {
                $segment = $segment.Trim()
                if ($segment -and $Defs.ContainsKey($segment)) { $names[$segment] = $true }
            }
        }
    }
    $names
}

function Get-UnreachableFunction {
    <#
    .SYNOPSIS
        Finds functions in bin/, lib/ and libexec/ that no entry point can call.
    .DESCRIPTION
        The same call graph as Get-DotSourceIssue, walked for reachability: seeds are bin/*,
        libexec/* and the test suite, and entering a function also enters every function
        nested in its body. Third-party scripts under $scoopdir\shims call into lib/ from
        outside the repository, so a lib function used only by them is reported as unreachable.
    .OUTPUTS
        One object per unreachable function: Path, Name, Line, Owner, Deprecated, ReplacedBy.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String] $Root
    )

    $index = Get-ScriptIndex -Root $Root
    $defs = $index.defs
    $fnBodies = $index.fnBodies
    $fnCmds = $index.fnCmds
    $fnNested = $index.fnNested
    $topCmds = $index.topCmds

    # Load order is ignored on purpose: anything a seed dot-sources is a seed too, and bin scripts
    # reached through `&` run in their caller's session, so they stay seeds without being entries.
    $seeds = @{}
    foreach ($e in Get-ChildItem "$Root\bin", "$Root\libexec" -Filter *.ps1) { $seeds[$e.FullName] = $true }
    # The test suite consumes lib functions too; a function only the tests reach is not dead code.
    foreach ($e in Get-ChildItem "$Root\test" -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue) { $seeds[$e.FullName] = $true }
    # An `& path` script runs, so the functions it calls are live even though it loads nothing here.
    foreach ($p in $index.invoked.Keys) { $seeds[$p] = $true }
    $loadQueue = [System.Collections.Generic.Queue[String]]::new()
    foreach ($s in @($seeds.Keys)) { $loadQueue.Enqueue($s) }
    while ($loadQueue.Count) {
        $current = $loadQueue.Dequeue()
        if (-not $current -or -not $index.topStmts.ContainsKey($current)) { continue }
        # Marking on enqueue: a lazy dot-source cycle between two files would loop forever.
        foreach ($k in $index.fnFileKeys[$current]) {
            foreach ($t in $index.fnDots[$k]) {
                if ($t -and -not $seeds.ContainsKey($t)) { $seeds[$t] = $true; $loadQueue.Enqueue($t) }
            }
        }
        foreach ($list in $index.topDots[$current]) { foreach ($t in $list) { if ($t -and -not $seeds.ContainsKey($t)) { $seeds[$t] = $true; $loadQueue.Enqueue($t) } } }
    }

    $reached = @{}
    $queue = [System.Collections.Generic.Queue[Object]]::new()
    foreach ($name in (Get-StringReachedNames -Index $index -Defs $defs).Keys) {
        foreach ($d in $defs[$name]) {
            $reached[$d.Key] = $true
            $queue.Enqueue(@{ File = $d.File; Calls = $fnCmds[$d.Key] })
            # Nested bodies run with their owner; marking alone would miss calls only they make.
            foreach ($k in $fnNested[$d.Key]) {
                $reached[$k] = $true
                $queue.Enqueue(@{ File = $d.File; Calls = $fnCmds[$k] })
            }
        }
    }
    foreach ($seed in @($seeds.Keys)) {
        foreach ($list in $topCmds[$seed]) { $queue.Enqueue(@{ File = $seed; Calls = $list }) }
    }

    while ($queue.Count) {
        $item = $queue.Dequeue()
        foreach ($call in $item.Calls) {
            $name = $call.GetCommandName()
            if (-not $name -or -not $defs.ContainsKey($name)) { continue }
            foreach ($d in $defs[$name]) {
                if ($reached.ContainsKey($d.Key)) { continue }
                $reached[$d.Key] = $true
                $queue.Enqueue(@{ File = $d.File; Calls = $fnCmds[$d.Key] })
                foreach ($k in $fnNested[$d.Key]) {
                    if ($reached.ContainsKey($k)) { continue }
                    $reached[$k] = $true
                    $queue.Enqueue(@{ File = $d.File; Calls = $fnCmds[$k] })
                }
            }
        }
    }

    $unreachable = @()
    foreach ($entry in $defs.GetEnumerator()) {
        foreach ($def in $entry.Value) {
            if ($reached.ContainsKey($def.Key)) { continue }
            $body = $fnBodies[$def.Key]
            $mark = Get-Deprecation $body

            $unreachable += [PSCustomObject]@{
                Path      = $def.File
                Name      = $entry.Key
                Line      = $body.Extent.StartLineNumber
                Owner     = if ($def.Owner) { $fnBodies[$def.Owner].Name } else { '' }
                Deprecated = $mark.Deprecated
                ReplacedBy = $mark.ReplacedBy
            }
        }
    }
    $unreachable | Sort-Object Path, Line
}

function Get-DeprecatedFunction {
    <#
    .SYNOPSIS
        Lists every function marked deprecated, reachable or not.
    .DESCRIPTION
        Deprecated means the body calls `Show-DeprecatedWarning $MyInvocation 'New-Name'`
        (filling ReplacedBy) or warns 'is deprecated' without naming a replacement. test/ files
        are skipped because fixtures mark functions deprecated on purpose.
    .OUTPUTS
        One object per deprecated function: Path, Name, Line, ReplacedBy.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String] $Root
    )

    $index = Get-ScriptIndex -Root $Root
    $Root = $index.root
    $defs = $index.defs
    $fnBodies = $index.fnBodies
    $deprecated = @()
    foreach ($entry in $defs.GetEnumerator()) {
        foreach ($def in $entry.Value) {
            if ($def.File -like "$Root\test\*") { continue }
            $mark = Get-Deprecation $fnBodies[$def.Key]
            if (-not $mark.Deprecated) { continue }
            $deprecated += [PSCustomObject]@{
                Path      = $def.File
                Name      = $entry.Key
                Line      = $fnBodies[$def.Key].Extent.StartLineNumber
                ReplacedBy = $mark.ReplacedBy
            }
        }
    }
    $deprecated | Sort-Object Path, Line
}

function Get-ManifestScripts {
    param([Object] $Node)

    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Node.PSObject.Properties) {
            if ($property.Name -in 'script', 'pre_install', 'post_install', 'pre_uninstall', 'post_uninstall') {
                if ($property.Value -is [String]) {
                    $property.Value
                } elseif ($property.Value -is [Array]) {
                    foreach ($item in $property.Value) {
                        if ($item -is [String]) { $item } else { Get-ManifestScripts $item }
                    }
                }
            } else {
                Get-ManifestScripts $property.Value
            }
        }
    } elseif ($Node -is [Array]) {
        $Node | ForEach-Object { Get-ManifestScripts $_ }
    }
}

function Get-ScriptCommands {
    param([String[]] $Scripts)

    $commands = [System.Collections.Generic.HashSet[String]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($text in $Scripts) {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$errors)
        $parts = if ($errors) { $text -split '\r?\n' } else { , $text }
        foreach ($part in $parts) {
            $partErrors = $null
            $partAst = [System.Management.Automation.Language.Parser]::ParseInput($part, [ref]$null, [ref]$partErrors)
            if ($partErrors) { continue }
            foreach ($cmd in $partAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
                $name = $cmd.GetCommandName()
                if ($name) { $null = $commands.Add($name) }
            }
        }
    }
    $commands
}

function Get-DeprecatedManifestUsage {
    <#
    .SYNOPSIS
        Finds manifest script fields that call functions Scoop has marked deprecated.
    .DESCRIPTION
        Matched calls must sit in command position in a script field; prose, comments and
        non-script fields never match, and manifests that fail to parse come back with
        Failed set.
    .OUTPUTS
        One object per manifest: Manifest, File (path relative to Dir), Found (hashtable
        name -> replacement), Failed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String] $Root,
        [Parameter(Mandatory = $true)]
        [String] $Dir,
        [String] $App = '*'
    )

    $deprecated = @(Get-DeprecatedFunction -Root $Root)

    $results = @()
    $dirFull = (Convert-Path $Dir).TrimEnd('\', '/')
    foreach ($file in (Get-ChildItem $Dir -Filter "$App.json" -Recurse)) {
        $relative = $file.FullName.Substring($dirFull.Length + 1)
        try {
            $json = Get-Content $file.FullName -Raw | ConvertFrom-Json
        } catch {
            $results += [PSCustomObject]@{ Manifest = $file.BaseName; File = $relative; Found = @{}; Failed = $true }
            continue
        }

        $found = @{}
        $commands = @(Get-ScriptCommands @(Get-ManifestScripts $json))
        foreach ($fn in $deprecated) {
            if ($commands -contains $fn.Name) { $found[$fn.Name] = $fn.ReplacedBy }
        }
        $results += [PSCustomObject]@{ Manifest = $file.BaseName; File = $relative; Found = $found; Failed = $false }
    }
    $results
}

Export-ModuleMember -Function Get-DotSourceIssue, Get-UnreachableFunction, Get-DeprecatedFunction, Get-DeprecatedManifestUsage
