#!/usr/bin/env bats

setup() {
  export PVE_MANAGER_TEST_DATA="$BATS_TEST_DIRNAME/fixtures/vms.json"
  export PVE_MANAGER_CURL_LOG="$BATS_TEST_TMPDIR/curl_calls"
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
}

@test "VMID displayed" {
  run commands/list
  [ "$status" -eq 0 ]
  [[ "$output" == *"101"* ]]
}

@test "list shows VM name" {
  run commands/list
  [[ "$output" == *"web01"* ]]
}

@test "shutdown sends correct API request" {
  run commands/shutdown 101
  [ "$status" -eq 0 ]
  grep "status/shutdown" "$BATS_TEST_TMPDIR/curl_calls"
}

@test "delete calls correct API endpoint" {
  run commands/delete 101 --yes
  grep "DELETE" "$BATS_TEST_TMPDIR/curl_calls"
  grep "purge=1" "$BATS_TEST_TMPDIR/curl_calls"
}

@test "shutdown multiple VMs" {
  run commands/shutdown 101 102
  count=$(grep -c "status/shutdown" "$BATS_TEST_TMPDIR/curl_calls")
  [ "$count" -eq 2 ]
}

@test "dry-run does not call API" {
  run commands/shutdown 101 --dry-run
  [ ! -f "$BATS_TEST_TMPDIR/curl_calls" ]
}

@test "unknown command fails" {
  run commands/nonsense
  [ "$status" -ne 0 ]
}
