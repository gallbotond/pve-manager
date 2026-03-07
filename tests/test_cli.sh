#!/usr/bin/env bash

source tests/test_framework.sh

export PVE_MANAGER_TEST_DATA="tests/fixtures/vms.json"

output=$(bash bin/main.sh list)

assert_contains "$output" "101" "VMID displayed"
assert_contains "$output" "web01" "list shows VM name"
assert_contains "$output" "running" "running status displayed"
assert_contains "$output" "node1" "node displayed"

summary
