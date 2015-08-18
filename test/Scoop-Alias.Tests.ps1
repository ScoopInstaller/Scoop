. "$psscriptroot\..\libexec\scoop-alias.ps1"

reset_aliases

describe "add_alias" {
  mock shimdir { "test\fixtures\shim" }
  mock set_config { }
  mock get_config { @{} }
  $shimdir = shimdir

  context "alias doesn't exist" {
    it "creates a new alias" {
      $alias_file = "$shimdir\scoop-rm.ps1"
      $alias_file | should not exist

      add_alias "rm" '"hello, world!"'
      iex $alias_file | should be "hello, world!"
    }
  }

  context "alias exists" {
    it "does not change existing alias" {
      $alias_file = "$shimdir\scoop-rm.ps1"
      new-item $alias_file -type file
      $alias_file | should exist

      add_alias "rm" "test"
      $alias_file | should contain ""
    }
  }

  aftereach {
    rm "test\fixtures\shim\scoop-rm.ps1" -ea ignore
  }
}

describe "rm_alias" {
  mock shimdir { "test\fixtures\shim" }
  $shimdir = shimdir
  mock set_config { }
  mock get_config { @{} }

  context "alias exists" {
    it "removes an existing alias" {
      $alias_file = "$shimdir\scoop-rm.ps1"
      add_alias "rm" '"hello, world!"'

      $alias_file | should exist
      mock get_config { @(@{"rm" = "scoop-rm"}) }

      rm_alias "rm"
      $alias_file | should not exist
    }
  }

  afterall {
    rm "test\fixtures\shim\scoop-rm.ps1" -ea ignore
  }
}
