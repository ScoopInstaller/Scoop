# Remove older cache of the given app
function tidy_cache([String] $app, [bool] $total_log = $false) {
    if ($app -like "*.json") { return }

    # Dependencies of the format "bucket/dependency" install in a directory of form
    # "dependency". So we need to extract the bucket from the name and only use the app
    # name
    $app = ($app -split '/|\\')[-1]

    $files = @(Get-ChildItem $cachedir | Where-Object -Property Name -Value "^$app#" -Match | Sort-Object LastWriteTime )
    if ($files.Count -le 2) {
        return
    }

    # do not remove last two files
    $files = $files[0..($files.Count - 3)]
    # remove only items more than one month old
    $files = $files| Where-Object {$_.LastWriteTime -lt (Get-Date).AddMonths(-1)}
    if ($files.Count -le 0) {
        if ($total_log) { Write-Host "No old cache to remove" -ForegroundColor Yellow }
        return
    }
    Write-Host -f yellow "Removing older cache for $app`:" -NoNewline

    $totalLength = ($files | Measure-Object -Property Length -Sum).Sum
    $files | ForEach-Object {
        Write-Host " $(($_ -split '#')[1])" -NoNewline
        Remove-Item $_.FullName
    }

    Write-Host ''
    if ($total_log) {
        Write-Host "Deleted: $($files.Count) $(pluralize $files.Count 'file' 'files'), $(filesize $totalLength)" -ForegroundColor Yellow
    }
}
