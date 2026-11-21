<#
.SYNOPSIS
    Report dead and deprecated functions, or deprecated usage in a bucket.
.DESCRIPTION
    Two views of dead and deprecated code: functions in the Scoop repository that no entry
    point can call, and deprecated calls in a bucket's manifest scripts with the replacement
    to apply. Report, not proof: shims call into lib/ from outside the repository.
.PARAMETER Root
    Scoop repository root that provides the function lists.
.PARAMETER Dir
    Bucket root to scan; passing it switches to bucket mode.
.PARAMETER App
    Manifest name to search. Placeholder is supported.
.PARAMETER PassThru
    In bucket mode, emit one object per deprecated call instead of the formatted report.
#>
param(
    [String] $Root = "$PSScriptRoot\..",
    [Parameter(Mandatory = $false)]
    [ValidateScript( {
        if (!(Test-Path $_ -Type Container)) {
            throw "$_ is not a directory!"
        } else {
            $true
        }
    })]
    [String] $Dir,
    [String] $App = '*',
    [Switch] $PassThru
)

Import-Module (Join-Path $Root 'supporting\Scoop.StaticAnalysis.psm1') -Force

if ($Dir) {
    $results = @(Get-DeprecatedManifestUsage -Root $Root -Dir $Dir -App $App)
    $hits = @($results | Where-Object { $_.Found.Count })
    $failed = @($results | Where-Object Failed)

    $rows = foreach ($hit in $hits) {
        foreach ($name in $hit.Found.Keys) {
            [PSCustomObject]@{ File = $hit.File; Function = $name; ReplacedBy = $hit.Found[$name] }
        }
    }
    $rows = @($rows | Sort-Object File, Function)

    $piped = $PassThru.IsPresent -or $MyInvocation.PipelineLength -gt $MyInvocation.PipelinePosition
    if ($piped) {
        $rows
    } elseif (-not $results) {
        Write-Host 'No manifests found.' -ForegroundColor Red
    } elseif (-not $hits) {
        Write-Host 'No deprecated function usage found.' -ForegroundColor Green
    } else {
        Write-Host ('{0} of {1} manifest(s) use deprecated functions:' -f $hits.Count, $results.Count) -ForegroundColor Yellow
        $rows | Format-Table File, Function, ReplacedBy -AutoSize | Out-Host
    }

    if ($failed) {
        if ($piped) {
            $failed | ForEach-Object { Write-Warning "Failed to parse $($_.File)" }
        } else {
            Write-Host ('{0} manifest(s) failed to parse:' -f $failed.Count) -ForegroundColor Red
            $failed | ForEach-Object { Write-Host "       > $($_.File)" -ForegroundColor DarkRed }
        }
    }
} else {
    $unreachable = @(Get-UnreachableFunction -Root $Root)
    $dead = @($unreachable | Where-Object { -not $_.Deprecated })
    $deprecated = @(Get-DeprecatedFunction -Root $Root)
    if (-not $dead -and -not $deprecated) {
        Write-Host 'No dead or deprecated functions found.' -ForegroundColor Green
        return
    }

    $fileColumn = @{ Label = 'File'; Expression = { Split-Path $_.Path -Leaf } }

    if ($dead) {
        Write-Host ('{0} dead function(s):' -f $dead.Count) -ForegroundColor Red
        $dead | Format-Table $fileColumn, Line, Name -AutoSize | Out-Host
    }

    if ($deprecated) {
        Write-Host ('{0} deprecated function(s):' -f $deprecated.Count) -ForegroundColor Yellow
        $deprecated | Format-Table $fileColumn, Line, Name, ReplacedBy -AutoSize | Out-Host
    }
}
