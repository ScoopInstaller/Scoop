
VER?=2.2.1
ZIP=shimexe-$(VER).zip
URL?=https://github.com/kiennq/scoop-better-shimexe/releases/download/$(VER)/$(ZIP)
LATEST_URL?=https://github.com/kiennq/scoop-better-shimexe/releases/latest
NEWVER=$(shell cat version.txt)

all: verify ## make download unzip verify

version.txt:
	@curl --max-redirs 0 -s -D - -o /dev/null $(LATEST_URL) | grep -i ^location | sed -E -e "s|.*/([^/]+)$$|\1|" >version.txt
	@printf "%s " "Latest version is:"
	@cat version.txt

check: version.txt ## Check the version number in version.txt and update if needed

bump: check ## Bump version number in Makefile
	@rm -f Makefile.bak
	@sed -i.bak -e 's|=$(VER)|=$(NEWVER)|' Makefile
	@cmp --quiet Makefile{,.bak} || echo "Makefile bumped from $(VER) to $(NEWVER)"

$(ZIP): version.txt
	curl -L -s -o $(ZIP) $(URL)
	@touch $@

download: $(ZIP)  ## Download shim from https://github.com/kiennq/scoop-better-shimexe

shim.exe: $(ZIP)
	unzip -z -j -o $(ZIP)
	@touch $@

unzip: shim.exe ## Unzip download

verify: shim.exe ## Verify SHA256 checksum for shim.exe
	sed -e "s|bin/||" checksum.sha256 | sha256sum -c

clean: ## Clean .zip files
	rm -f *.zip

help: ## Display help text
	@printf "%-8s %s\n" Target Description
	@printf "%-8s %s\n" '--------' '------------------------------------------'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "%-8s %s\n", $$1, $$2}'

.PHONY: all
.PHONY: bump
.PHONY: check
.PHONY: clean
.PHONY: download
.PHONY: help
.PHONY: unzip
.PHONY: verify
