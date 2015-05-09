set-alias scoop "$psscriptroot/../bin/scoop.ps1"

describe "'scoop reset scoop'" {
  beforeall {
    remove-item "~/.bashrc.scoop" -ea ignore
  }

  function alias_count {
    (gc "~/.bashrc" | where { $_ -eq 'alias scoop="powershell scoop.ps1"' } | measure).count
  }

  function backup_bashrc_if_exists {
    # back up .bashrc if it exists
    if(test-path "~/.bashrc") {
      move-item "~/.bashrc" "~/.bashrc.scoop"
    }
  }

  function restore_bashrc_if_exists {
    # restore backup
    if(test-path "~/.bashrc.scoop") {
      move-item "~/.bashrc.scoop" "~/.bashrc"

      "~/.bashrc.scoop" | should not exist
      "~/.bashrc" | should exist
    }
  }

  context "no .bashrc" {
    it "creates .bashrc when it doesn't exist" {
      backup_bashrc_if_exists

      "~/.bashrc" | should not exist
      scoop reset scoop
      "~/.bashrc" | should exist
      alias_count | should be 1

      # cleanup
      remove-item "~/.bashrc"

      restore_bashrc_if_exists
    }
  }

  context "bash scoop alias exists" {
    it "does not create another bash scoop alias" {
      # call it once to create it if it doesn't exist
      scoop reset scoop
      alias_count | should be 1

      scoop reset scoop
      alias_count | should be 1
    }
  }

  context "bash scoop alias doesn't exist" {
    it "creates bash scoop alias" {
      backup_bashrc_if_exists
      new-item -type file "~/.bashrc"

      alias_count | should be 0

      scoop reset scoop
      alias_count | should be 1

      remove-item "~/.bashrc"
      restore_bashrc_if_exists
    }
  }
}