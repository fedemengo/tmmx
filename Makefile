PREFIX ?= $(HOME)/.local

.PHONY: install test test-e2e

install:
	install -d "$(PREFIX)/bin"
	install -m 755 bin/tmmx "$(PREFIX)/bin/tmmx"

test:
	sh -n tmmx.tmux bin/tmmx scripts/*.sh tests/test-common.sh
	sh tests/test-common.sh

test-e2e:
	sh tests/e2e/run.sh
