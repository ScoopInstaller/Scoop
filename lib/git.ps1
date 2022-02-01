function git_proxy_cmd {
    $proxy = get_config 'proxy'
    $cmd = "git $($args | ForEach-Object { "$_ " })"
    if ($proxy -and $proxy -ne 'none') {
        $cmd = "SET HTTPS_PROXY=$proxy&&SET HTTP_PROXY=$proxy&&$cmd"
    }
    cmd.exe /d /c $cmd
}

function git_clone {
    git_proxy_cmd clone $args
}

function git_ls_remote {
    git_proxy_cmd ls-remote $args
}

function git_cmd {
    git_proxy_cmd $args
}
