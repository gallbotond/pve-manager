#!/usr/bin/env bats

setup() {
  export PVE_MANAGER_TEST_DATA="$BATS_TEST_DIRNAME/fixtures/vms.json"
}

@test "list prints VM IDs" {
  run bin/main.sh list

  [ "$status" -eq 0 ]
  [[ "$output" == *"101"* ]]
  [[ "$output" == *"102"* ]]
}

@test "dry-run shutdown works" {
  run bin/main.sh shutdown 101 --dry-run

  [ "$status" -eq 0 ]
}

@test "unknown command fails" {
  run bin/main.sh nonsense

  [ "$status" -ne 0 ]
}