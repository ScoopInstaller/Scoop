BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\getopt.ps1"
}

Describe 'getopt' -Tag 'Scoop' {
    It 'handle short option with required argument missing' {
        $null, $null, $err = getopt '-x' 'x:' ''
        $err | Should-Be 'Option -x requires an argument.'

        $null, $null, $err = getopt '-xy' 'x:y' ''
        $err | Should-Be 'Option -x requires an argument.'
    }

    It 'handle long option with required argument missing' {
        $null, $null, $err = getopt '--arb' '' 'arb='
        $err | Should-Be 'Option --arb requires an argument.'
    }

    It 'handle space in quote' {
        $opt, $rem, $err = getopt '-x', 'space arg' 'x:' ''
        $err | Should-BeNull
        $opt.x | Should-Be 'space arg'
    }

    It 'handle unrecognized short option' {
        $null, $null, $err = getopt '-az' 'a' ''
        $err | Should-Be 'Option -z not recognized.'
    }

    It 'handle unrecognized long option' {
        $null, $null, $err = getopt '--non-exist' '' ''
        $err | Should-Be 'Option --non-exist not recognized.'

        $null, $null, $err = getopt '--global', '--another' 'abc:de:' 'global', 'one'
        $err | Should-Be 'Option --another not recognized.'
    }

    It 'remaining args returned' {
        $opt, $rem, $err = getopt '-g', 'rem' 'g' ''
        $err | Should-BeNull
        $opt.g | Should-BeTrue
        $rem | Should-NotBeNull
        $rem.length | Should-Be 1
        $rem[0] | Should-Be 'rem'
    }

    It 'get a long flag and a short option with argument' {
        $a = '--global -a 32bit test' -split ' '
        $opt, $rem, $err = getopt $a 'ga:' 'global', 'arch='

        $err | Should-BeNull
        $opt.global | Should-BeTrue
        $opt.a | Should-Be '32bit'
    }

    It 'handles regex characters' {
        $a = '-?'
        & { $opt, $rem, $err = getopt $a 'ga:' 'global' 'arch=' }
        & { $null, $null, $null = getopt $a '?:' 'help' }
    }

    It 'handles short option without required argument' {
        $null, $null, $err = getopt '-x' 'x' ''
        $err | Should-BeNull
    }

    It 'handles long option without required argument' {
        $opt, $null, $err = getopt '--long-arg' '' 'long-arg'
        $err | Should-BeNull
        $opt.'long-arg' | Should-BeTrue
    }

    It 'handles long option with required argument' {
        $opt, $null, $err = getopt '--long-arg', 'test' '' 'long-arg='
        $err | Should-BeNull
        $opt.'long-arg' | Should-Be 'test'
    }

    It 'handles the option terminator' {
        $opt, $rem, $err = getopt '--long-arg', '--' '' 'long-arg'
        $err | Should-BeNull
        $opt.'long-arg' | Should-BeTrue
        $rem | Should-BeCollection -Count 0
    }

    It 'handles remainder args after the option terminator' {
        $opt, $rem, $err = getopt '--long-arg', '--', '-x', '-y' 'xy' 'long-arg'
        $err | Should-BeNull
        $opt.'long-arg' | Should-BeTrue
        $opt.Keys | Should-NotContainCollection 'x'
        $opt.Keys | Should-NotContainCollection 'y'
        $rem[0] | Should-Be '-x'
        $rem[1] | Should-Be '-y'
    }

    It 'handles PowerShell stop-parsing token' {
        $opt, $rem, $err = getopt '--long-arg', '--%' '' 'long-arg'
        $err | Should-BeNull
        $opt.'long-arg' | Should-BeTrue
        $rem | Should-BeCollection -Count 0
    }

    It 'handles remainder args after PowerShell stop-parsing token' {
        $opt, $rem, $err = getopt @('--long-arg', '--%', '--from', 'there', '--to', 'here') '' 'long-arg'
        $err | Should-BeNull
        $opt.Keys | Should-NotContainCollection 'from'
        $opt.Keys | Should-NotContainCollection 'to'
        $rem | Should-BeCollection @('--from', 'there', '--to', 'here')
    }

}
