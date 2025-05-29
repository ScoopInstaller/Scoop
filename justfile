test:
    vagrant snapshot restore windows clean || (vagrant up windows && vagrant snapshot save windows clean)
    vagrant ssh windows -- powershell ./scoop/apps/scoop/current/test/bin/init.ps1
    vagrant ssh windows -- powershell ./scoop/apps/scoop/current/test/bin/test.ps1

clean:
    -vagrant destroy windows --force
