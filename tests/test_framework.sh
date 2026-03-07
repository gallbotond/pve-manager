#!/usr/bin/env bash

PASS_COUNT=0
FAIL_COUNT=0

pass() {
	echo "[PASS] $1"
	((PASS_COUNT++))
}

fail() {
    echo "[FAIL] $1"
    echo "Output was:"
    echo "$output"
    ((FAIL_COUNT++))
}

assert_contains() {
	local output="$1"
	local expected="$2"
	local name="$3"

	if grep -q "$expected" <<<"$output"; then
		pass "$name"
	else
		fail "$name"
		echo "Expected to find: $expected"
	fi
}

summary() {
	echo
	echo "Tests passed: $PASS_COUNT"
	echo "Tests failed: $FAIL_COUNT"

	if [[ $FAIL_COUNT -ne 0 ]]; then
		exit 1
	fi
}
