SHELL := /bin/bash

lint:
	shellcheck -e SC2034 -e SC1091 -x bin/*.sh lib/*.sh

lint-ci:
	shellcheck -S error -x bin/*.sh lib/*.sh

test:
	bash -n bin/main.sh
	bash -n lib/*.sh

test-cli:
	bash tests/run_tests.sh

fmt:
	shfmt -d bin lib

check: lint test
