$global:profiles = @{}

function start_profiling([string] $key) {
    if ($global:profiles.ContainsKey($key) -ne $true) {
        $global:profiles[$key] = @{
            count = 0
            stopwatch = New-Object System.Diagnostics.Stopwatch
            measures = New-Object System.Collections.ArrayList
        }
    }

    $global:profiles[$key].count += 1
    $global:profiles[$key].stopwatch.Restart()
}

function stop_profiling([string] $key) {
    $global:profiles[$key].stopwatch.Stop()
    $global:profiles[$key].measures.Add($global:profiles[$key].stopwatch.ElapsedMilliseconds)
}

function get_profile($key) {
    $p = $global:profiles[$key]

    $result = [ordered]@{}
    $result.Key = $key
    $result.Count = $p.count
    $result."Sum (ms)" = $p.measures | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $result."Avg (ms)" = $p.measures | Measure-Object -Average | Select-Object -ExpandProperty Average

    [PSCustomObject] $result
}

function get_all_profiles() {
    $results = @()

    foreach ($key in $global:profiles.Keys) {
        $results += get_profile $key
    }

    $results
}
