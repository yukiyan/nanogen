VERSION := $(shell sed -n 's/.*\.version *= *"\([^"]*\)".*/\1/p' build.zig.zon)
DIST_DIR := dist
TARGETS := aarch64-macos:darwin_arm64 x86_64-macos:darwin_amd64 aarch64-linux-musl:linux_arm64 x86_64-linux-musl:linux_amd64

.PHONY: build release release-fast test run clean install uninstall dist dist-clean gh-release

build:
	zig build

release:
	zig build -Doptimize=ReleaseSmall

release-fast:
	zig build -Doptimize=ReleaseFast

test:
	zig build test

run:
	zig build run -- $(ARGS)

clean:
	rm -rf zig-out .zig-cache

install: release
	install -Dm755 zig-out/bin/nanogen $(HOME)/.local/bin/nanogen

uninstall:
	rm -f $(HOME)/.local/bin/nanogen

dist: dist-clean
	@mkdir -p $(DIST_DIR)
	@set -e; for entry in $(TARGETS); do \
		zig_target=$${entry%%:*}; \
		label=$${entry##*:}; \
		echo "Building $$zig_target..."; \
		zig build -Doptimize=ReleaseSmall -Dtarget=$$zig_target; \
		tar -czf $(DIST_DIR)/nanogen_$(VERSION)_$${label}.tar.gz -C zig-out/bin nanogen; \
	done
	@cd $(DIST_DIR) && shasum -a 256 *.tar.gz > nanogen_$(VERSION)_checksums.txt

dist-clean:
	rm -rf $(DIST_DIR)

gh-release: dist
	gh release create v$(VERSION) $(DIST_DIR)/* --title "v$(VERSION)" --notes ""
