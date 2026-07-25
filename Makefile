# Source centralized config; build.env provides all defaults.
# Override with: make build ARCH=amd64 DEBIAN_CODENAME=forchy
SHELL := /bin/bash

# Load build.env if it exists (provides ARCH, DEBIAN_CODENAME, etc.)
-include build.env

ARCH ?= arm64

.PHONY: help config build build-arm64 build-amd64 clean test lint qemu-arm64

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

config: ## Run lb config (override ARCH=, DEBIAN_CODENAME=, etc.)
	bash scripts/gen-arch-packages.sh $(ARCH) config/package-lists
	bash auto/config $(ARCH)

build: config ## Build ISO (override ARCH=amd64 or ARCH=arm64)
	lb build

build-arm64: ## Build arm64 ISO via Multipass
	ARCH=arm64 bash scripts/build-iso-multipass.sh

build-amd64: ## Build amd64 ISO (requires native amd64 host)
	$(MAKE) build ARCH=amd64

clean: ## Clean live-build artifacts
	lb clean --purge || true
	rm -rf chroot binary .build cache

test: ## Run upgrade-path test suite
	tests/upgrade/run.sh || { tests/upgrade/cleanup.sh; exit 1; }
	tests/upgrade/cleanup.sh

lint: ## Run shellcheck + bash -n on all shell files
	@find . -type f \( -name '*.sh' -o -name '*.hook.chroot' -o -name '*.hook.binary' \) \
		! -path './chroot/*' ! -path './.git/*' \
		-exec sh -c 'echo "checking: $$1"; shellcheck "$$1" && bash -n "$$1"' _ {} \;

qemu-arm64: ## Boot arm64 ISO in QEMU
	bash scripts/qemu-arm64.sh
