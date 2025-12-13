.PHONY: lint fmt check

SHELL := /usr/bin/env bash

# Discover shell scripts (excluding common vendor dirs)
SCRIPTS := $(shell find . -type f -name "*.sh" \
  -not -path "*/.venv/*" -not -path "*/node_modules/*" -not -path "*/dist/*")

lint:
	@if command -v shellcheck >/dev/null 2>&1; then \
	  echo "Running shellcheck..."; \
	  shellcheck -S style $(SCRIPTS); \
	else \
	  echo "shellcheck not found. Install: pacman -S shellcheck | apt-get install shellcheck | brew install shellcheck"; \
	fi

fmt:
	@if command -v shfmt >/dev/null 2>&1; then \
	  echo "Running shfmt..."; \
	  shfmt -w .; \
	else \
	  echo "shfmt not found. Install: pacman -S shfmt | apt-get install shfmt | brew install shfmt"; \
	fi

check:
	@echo "Syntax checking shell scripts..."; \
	for f in $(SCRIPTS); do \
	  bash -n "$$f" || exit 1; \
	done; \
	echo "OK"

