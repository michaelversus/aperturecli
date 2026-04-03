# Define variables.
prefix ?= /usr/local
bindir = $(prefix)/bin

# Command building targets.
build:
	swift build -c release --disable-sandbox

install: build
	install -d "$(bindir)"
	install ".build/release/NSAssetsCLI" "$(bindir)/nsassetscli"
	ln -sf "$(bindir)/nsassetscli" "$(bindir)/NSAssetsCLI"

uninstall:
	rm -f "$(bindir)/nsassetscli"
	rm -f "$(bindir)/NSAssetsCLI"

clean:
	rm -rf .build

.PHONY: build install uninstall clean
