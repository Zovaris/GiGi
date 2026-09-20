SHELL := /bin/bash
PLIST := Resources/Info.plist
BUMP ?= patch
VERSION ?=

.PHONY: help build test strings check icon next-version version tap install uninstall clean

help:
	@echo "GiGi"
	@echo "  make build                     bin/gigi and app/GiGi.app"
	@echo "  make test                      compile and run the test harness"
	@echo "  make strings                   lint the Info.plist and the localizations"
	@echo "  make check                     build, test and lint (what CI runs)"
	@echo "  make icon                      redraw Resources/GiGi.icns"
	@echo "  make next-version [BUMP=..]    print the next version and change nothing"
	@echo "  make version [BUMP=..|VERSION=x.y.z] [DRY=1] [NO_PUSH=1]"
	@echo "                                 bump, commit, tag and push a release"
	@echo "  make tap [VERSION=x.y.z]       point the Homebrew cask at a published release"
	@echo "  make install [APP=1]           install.sh, with the menu bar app when APP=1"
	@echo "  make uninstall                 remove the LaunchAgent"
	@echo "  make clean                     drop the build products"
	@echo
	@echo "  version: $(shell plutil -extract CFBundleShortVersionString raw $(PLIST))"

build:
	./build.sh

test:
	@mkdir -p .build/tests
	swiftc -swift-version 5 -framework CoreGraphics -framework IOKit Sources/Core/*.swift Tests/*.swift -o .build/tests/run
	.build/tests/run

strings:
	plutil -lint $(PLIST) Resources/en.lproj/Localizable.strings Resources/es.lproj/Localizable.strings
	swift tools/check-strings.swift

check: build test strings

icon:
	swift tools/make-icon.swift

next-version:
	@tools/version.sh --dry-run $(if $(VERSION),--version $(VERSION),--bump $(BUMP))

version: $(if $(DRY),,check)
	@tools/version.sh $(if $(VERSION),--version $(VERSION),--bump $(BUMP)) $(if $(DRY),--dry-run) $(if $(NO_PUSH),--no-push)

tap:
	@tools/tap.sh $(VERSION)

install:
	./install.sh $(if $(APP),--app)

uninstall:
	./uninstall.sh

clean:
	rm -rf .build/tests bin app
