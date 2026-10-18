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
    # Truth value implied by a `get_config X` guard, or $null when none; `-or` pins no single
    # value, and neither does a comparison chained onto the call: that branch is about the
    # value, not the config being set.
    param([System.Management.Automation.Language.Ast] $Condition)

    if (-not $Condition) { return }
    $text = $Condition.Extent.Text
    if ($text -match '\s-or\s') { return }

    $name = [regex]::Match($text, 'get_config\s+([A-Za-z0-9_-]+)')
    if (-not $name.Success) { return }
    # An operator directly behind the call's closing paren applies to the config value;
    # one further out, like `-and ($app -ne 'scoop')`, does not.
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
    $fnBodies = @{}      # Key -> FunctionDefinitionAst
    $fnCmds = @{}        # Key -> CommandAst[], nested bodies excluded
    $fnDots = @{}        # Key -> paths dot-sourced in the body
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
                if ($invocation -eq 'Ampersand' -and $target) { $invoked[$target] = $true }
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
        files = $files; defs = $defs; topStmts = $topStmts; topCmds = $topCmds; topDots = $topDots
        fnBodies = $fnBodies; fnCmds = $fnCmds; fnDots = $fnDots; fnFileKeys = $fnFileKeys
        fnNested = $fnNested; fnAboveDots = $fnAboveDots; cmdConstraints = $cmdConstraints
        invoked = $invoked; hostSet = $hostSet; entries = $entries; asts = $asts
    }
    $script:indexCache[$Root] = $result
    $result
}

function Get-DotSourceIssue {
    <#
    .SYNOPSIS
        Finds functions a script calls but cannot see when it runs.
    .DESCRIPTION
        Scoop dot-sources lib/*.ps1 as plain scripts, so a function can exist in the repository
        and still be undefined at the call site: a file the entry point never loads, or loads
        after the call. Entry points are bin/*.ps1 and libexec/*.ps1 (dispatched through
        `exec`, inheriting whatever bin/scoop.ps1 loaded); lib/*.ps1 never are. Contradictory
        `get_config` branches and non-repository names are skipped, and calls inside nested
        function bodies are checked with their owner's visibility.
    .OUTPUTS
        One object per unresolved call: Path, Entry, Chain, Line, Name, DefinedIn.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String] $Root
    )

    # The -like patterns below need the canonical form: a relative or `..`-containing
    # Root would never match the absolute paths the index records.
    $index = Get-ScriptIndex -Root $Root
    $Root = $index.root
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
                $queue.Enqueue(@{ File = $entry; Stmt = $i; Calls = $topCmds[$entry][$i]; Loaded = $loaded.Clone(); Fns = @{}; Env = @{}; Chain = @((Split-Path $entry -Leaf)) })
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
                    # Top-level statements run in order: an entry-file definition below the
                    # calling statement has not run yet when the call executes.
                    if ($null -ne $item.Stmt -and $d.File -eq $item.File -and $d.Stmt -gt $item.Stmt) { continue }
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
    $asts = $index.asts

    # Load order is ignored on purpose: anything a seed dot-sources is a seed too, and bin scripts
    # reached through `&` run in their caller's session, so they stay seeds without being entries.
    $seeds = @{}
    foreach ($e in Get-ChildItem "$Root\bin", "$Root\libexec" -Filter *.ps1) { $seeds[$e.FullName] = $true }
    # The test suite consumes lib functions too; a function only the tests reach is not dead code.
    foreach ($e in Get-ChildItem "$Root\test" -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue) { $seeds[$e.FullName] = $true }
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
    $reachedByName = @{}
    foreach ($seed in @($seeds.Keys)) {
        $visited = @{}
        $queue = [System.Collections.Generic.Queue[Object]]::new()
        foreach ($list in $index.topCmds[$seed]) { $queue.Enqueue(@{ File = $seed; Calls = $list }) }

        while ($queue.Count) {
            $item = $queue.Dequeue()
            foreach ($call in $item.Calls) {
                $name = $call.GetCommandName()
                if (-not $name -or -not $defs.ContainsKey($name)) { continue }
                foreach ($d in $defs[$name]) {
                    if ($visited.ContainsKey($d.Key)) { continue }
                    $visited[$d.Key] = $true
                    $reached[$d.Key] = $true
                    $queue.Enqueue(@{ File = $d.File; Calls = $fnCmds[$d.Key] })

                    # Nested bodies run with their owner; marking alone would miss calls only they make.
                    foreach ($k in $fnNested[$d.Key]) {
                        if ($visited.ContainsKey($k)) { continue }
                        $visited[$k] = $true
                        $reached[$k] = $true
                        $queue.Enqueue(@{ File = $d.File; Calls = $fnCmds[$k] })
                    }
                }
            }
        }
    }

    # Names the code hands to `& $var` rather than calling directly, including wildcard strings
    # searched as text: lib/depends.ps1 looks for '*Expand-DarkArchive *' inside manifest scripts.
    # Only wildcard strings are split, so a path like '.\lib\versions.ps1' does not match `versions`.
    # Command names, member names and hashtable keys are syntax rather than data, so their
    # extents are skipped: a call is already covered by the walk above, and `$status.latest_version`
    # or a Pester `Run` key is not a call to a function of the same name.
    foreach ($file in $index.files) {
        $syntaxStart = @{}
        foreach ($cmd in $asts[$file].FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            if ($cmd.GetCommandName()) { $syntaxStart[$cmd.CommandElements[0].Extent.StartOffset] = $true }
        }
        foreach ($member in $asts[$file].FindAll({ param($n) $n -is [System.Management.Automation.Language.MemberExpressionAst] }, $true)) {
            $syntaxStart[$member.Member.Extent.StartOffset] = $true
        }
        foreach ($table in $asts[$file].FindAll({ param($n) $n -is [System.Management.Automation.Language.HashtableAst] }, $true)) {
            foreach ($pair in $table.KeyValuePairs) { $syntaxStart[$pair.Item1.Extent.StartOffset] = $true }
        }

        $asts[$file].FindAll({
                param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] -or
                $n -is [System.Management.Automation.Language.ExpandableStringExpressionAst]
            }, $true) | ForEach-Object {
            if ($syntaxStart.ContainsKey($_.Extent.StartOffset)) { return }
            $value = $_.Value.Trim()
            if (-not $value) { return }
            if ($defs.ContainsKey($value)) {
                $reachedByName[$value] = $true
                return
            }
            if ($value -notmatch '[\*\?]') { return }
            foreach ($segment in ($value -split '[\*\?]')) {
                $segment = $segment.Trim()
                if ($segment -and $defs.ContainsKey($segment)) { $reachedByName[$segment] = $true }
            }
        }
    }
    foreach ($name in $reachedByName.Keys) {
        foreach ($d in $defs[$name]) { $reached[$d.Key] = $true }
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
        (filling ReplacedBy) or warns 'is deprecated' without naming a replacement.
        Get-UnreachableFunction reports only the unreachable subset, and test/ files are
        skipped because fixtures mark functions deprecated on purpose.
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
    $deprecated = @()
    foreach ($entry in $index.defs.GetEnumerator()) {
        foreach ($def in $entry.Value) {
            if ($def.File -like "$Root\test\*") { continue }
            $mark = Get-Deprecation $index.fnBodies[$def.Key]
            if (-not $mark.Deprecated) { continue }
            $deprecated += [PSCustomObject]@{
                Path      = $def.File
                Name      = $entry.Key
                Line      = $index.fnBodies[$def.Key].Extent.StartLineNumber
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

function Get-ScriptLines {
    param([String[]] $Scripts)

    foreach ($text in $Scripts) {
        foreach ($line in ($text -split '\r?\n')) {
            if ($line -match '^\s*//') { continue }
            if ($line.Contains('#')) {
                # Truncate at a `#` that sits outside a string.
                $quotes = 0
                for ($i = 0; $i -lt $line.Length; $i++) {
                    if ($line[$i] -eq '#' -and $quotes % 2 -eq 0) { $line = $line.Substring(0, $i); break }
                    if ($line[$i] -eq "'" -or $line[$i] -eq '"') { $quotes++ }
                }
            }
            $line
        }
    }
}

function Test-ScriptCall {
    param(
        [String[]] $Lines,
        [String] $Name,
        [String] $Pattern
    )

    foreach ($line in $Lines) {
        foreach ($match in [regex]::Matches($line, $Pattern)) {
            $nameStart = $match.Index + $match.Length - $Name.Length
            if ([regex]::Matches($line.Substring(0, $nameStart), '["'']').Count % 2 -eq 0) { return $true }
        }
    }
    $false
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
    $callPatterns = @{}
    foreach ($fn in $deprecated) {
        $callPatterns[$fn.Name] = '(?i)(?:^|[\s&|;(.{=])' + [regex]::Escape($fn.Name) + '(?=[\s(){};,|]|$)'
    }

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
        $lines = @(Get-ScriptLines @(Get-ManifestScripts $json))
        if ($lines) {
            foreach ($fn in $deprecated) {
                if (Test-ScriptCall $lines $fn.Name $callPatterns[$fn.Name]) {
                    $found[$fn.Name] = $fn.ReplacedBy
                }
            }
        }
        $results += [PSCustomObject]@{ Manifest = $file.BaseName; File = $relative; Found = $found; Failed = $false }
    }
    $results
}

Export-ModuleMember -Function Get-DotSourceIssue, Get-UnreachableFunction, Get-DeprecatedFunction, Get-DeprecatedManifestUsage
