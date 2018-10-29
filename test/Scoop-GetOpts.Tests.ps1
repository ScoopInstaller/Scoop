. "$psscriptroot\Scoop-TestLib.ps1"
. "$psscriptroot\..\lib\getopt.ps1"

describe "getopt" -Tag 'Scoop' {
    it 'handle short option with required argument missing' {
        $null, $null, $err = getopt '-x' 'x:' ''
        $err | should -be 'Option -x requires an argument.'

        $null, $null, $err = getopt '-xy' 'x:y' ''
        $err | should -be 'Option -x requires an argument.'
    }

    it 'handle long option with required argument missing' {
        $null, $null, $err = getopt '--arb' '' 'arb='
        $err | should -be 'Option --arb requires an argument.'
    }

    it 'handle unrecognized short option' {
        $null, $null, $err = getopt '-az' 'a' ''
        $err | should -be 'Option -z not recognized.'
    }

    it 'handle unrecognized long option' {
        $null, $null, $err = getopt '--non-exist' '' ''
        $err | should -be 'Option --non-exist not recognized.'

        $null, $null, $err = getopt '--global','--another' 'abc:de:' 'global','one'
        $err | should -be 'Option --another not recognized.'
    }

    it 'remaining args returned' {
        $opt, $rem, $err = getopt '-g','rem' 'g' ''
        $err | should -benullorempty
        $opt.g | should -betrue
        $rem | should -not -benullorempty
        $rem.length | should -be 1
        $rem[0] | should -be 'rem'
    }

    it 'get a long flag and a short option with argument' {
        $a = "--global -a 32bit test" -split ' '
        $opt, $rem, $err = getopt $a 'ga:' 'global','arch='

        $err | should -benullorempty
        $opt.global | should -betrue
        $opt.a | should -be '32bit'
    }

    it 'handles regex characters' {
        $a = "-?"
        { $opt, $rem, $err = getopt $a 'ga:' 'global' 'arch=' } | should -not -throw
        { $null, $null, $null = getopt $a '?:' 'help' | should -not -throw }
    }

    it 'handles short option without required argument' {
        $null, $null, $err = getopt '-x' 'x' ''
        $err | should -benullorempty
    }

    it 'handles long option without required argument' {
        $opt, $null, $err = getopt '--long-arg' '' 'long-arg'
        $err | should -benullorempty
        $opt."long-arg" | should -betrue
    }

    it 'handles long option with required argument' {
        $opt, $null, $err = getopt '--long-arg', 'test' '' 'long-arg='
        $err | should -benullorempty
        $opt."long-arg" | should -be "test"
    }
}
