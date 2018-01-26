."$psscriptroot\Scoop-TestLib.ps1"
."$psscriptroot\..\lib\getopt.ps1"

Describe "getopt" {
  It 'handle short option with required argument missing' {
    $null,$null,$err = getopt '-x' 'x:' ''
    $err | Should be 'Option -x requires an argument.'

    $null,$null,$err = getopt '-xy' 'x:y' ''
    $err | Should be 'Option -x requires an argument.'
  }

  It 'handle long option with required argument missing' {
    $null,$null,$err = getopt '--arb' '' 'arb='
    $err | Should be 'Option --arb requires an argument.'
  }

  It 'handle unrecognized short option' {
    $null,$null,$err = getopt '-az' 'a' ''
    $err | Should be 'Option -z not recognized.'
  }

  It 'handle unrecognized long option' {
    $null,$null,$err = getopt '--non-exist' '' ''
    $err | Should be 'Option --non-exist not recognized.'

    $null,$null,$err = getopt '--global','--another' 'abc:de:' 'global','one'
    $err | Should be 'Option --another not recognized.'
  }

  It 'remaining args returned' {
    $opt,$rem,$err = getopt '-g','rem' 'g' ''
    $err | Should be $null
    $opt.g | Should be $true
    $rem | Should not be $null
    $rem.length | Should be 1
    $rem[0] | Should be 'rem'
  }

  It 'get a long flag and a short option with argument' {
    $a = "--global -a 32bit test" -split ' '
    $opt,$rem,$err = getopt $a 'ga:' 'global','arch='

    $err | Should be $null
    $opt.global | Should be $true
    $opt.a | Should be '32bit'
  }

  It 'handles regex characters' {
    $a = "-?"
    { $opt,$rem,$err = getopt $a 'ga:' 'global' 'arch=' } | Should not throw
    { $null,$null,$null = getopt $a '?:' 'help' | Should not throw }
  }

  It 'handles short option without required argument' {
    $null,$null,$err = getopt '-x' 'x' ''
    $err | Should be $null
  }

  It 'handles long option without required argument' {
    $opt,$null,$err = getopt '--long-arg' '' 'long-arg'
    $err | Should be $null
    $opt."long-arg" | Should be $true
  }

  It 'handles long option with required argument' {
    $opt,$null,$err = getopt '--long-arg','test' '' 'long-arg='
    $err | Should be $null
    $opt."long-arg" | Should be "test"
  }
}
