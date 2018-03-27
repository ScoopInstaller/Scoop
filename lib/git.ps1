function git_proxy_cmd {
    $proxy = $(scoop config proxy)
    $cmd = "git $($args | ForEach-Object { "$_ " })"
    if($proxy) {
        $cmd = "SET HTTPS_PROXY=$proxy&&SET HTTP_PROXY=$proxy&&$cmd"
    }
    & "$env:COMSPEC" /c $cmd
}

function git_clone {
    git_proxy_cmd clone $args
}

function git_ls_remote {
    git_proxy_cmd ls-remote $args
}

function git_pull {
    git_proxy_cmd pull $args
}

function git_fetch {
    git_proxy_cmd fetch $args
}

function git_log {
    git_proxy_cmd --no-pager log $args
}
