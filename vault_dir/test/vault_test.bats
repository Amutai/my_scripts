#!/usr/bin/env bats

setup() {
  TEST_DIR="$(mktemp -d)"
  export PATH="$TEST_DIR/mocks:$PATH"

  # Create a mock 'age' that just passes through data
  mkdir -p "$TEST_DIR/mocks"
  cat > "$TEST_DIR/mocks/age" <<'EOF'
#!/bin/bash
if [[ "$1" == "-p" ]]; then
  cat  # encrypt: passthrough stdin
elif [[ "$1" == "-d" ]]; then
  shift; cat "$@"  # decrypt: passthrough file
fi
EOF
  chmod +x "$TEST_DIR/mocks/age"

  # Source script dir
  SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

teardown() {
  rm -rf "$TEST_DIR"
}

@test "usage output shows lock and unlock" {
  run bash "$SCRIPT_DIR/vault.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"lock"* ]]
  [[ "$output" == *"unlock"* ]]
}

@test "lock fails on nonexistent path" {
  run bash "$SCRIPT_DIR/vault.sh" lock "/nonexistent_path_xyz"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "unlock fails on nonexistent file" {
  run bash "$SCRIPT_DIR/vault.sh" unlock "/nonexistent_file.age"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
}

@test "lock encrypts a file" {
  echo "secret data" > "$TEST_DIR/testfile.txt"

  # Provide inputs: output filename, don't delete original
  run bash -c "printf '%s\n' '$TEST_DIR/testfile.txt.age' 'n' | bash '$SCRIPT_DIR/vault.sh' lock '$TEST_DIR/testfile.txt'"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/testfile.txt.age" ]
  [[ "$output" == *"Encrypted"* ]]
}

@test "lock encrypts a directory" {
  mkdir -p "$TEST_DIR/mydir"
  echo "hello" > "$TEST_DIR/mydir/file.txt"

  run bash -c "printf '%s\n' '$TEST_DIR/mydir.age' 'n' | bash '$SCRIPT_DIR/vault.sh' lock '$TEST_DIR/mydir'"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/mydir.age" ]
  [[ "$output" == *"Encrypted"* ]]
}

@test "lock deletes original when confirmed" {
  echo "delete me" > "$TEST_DIR/delme.txt"

  run bash -c "printf '%s\n' '$TEST_DIR/delme.txt.age' 'y' | bash '$SCRIPT_DIR/vault.sh' lock '$TEST_DIR/delme.txt'"
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_DIR/delme.txt" ]
  [[ "$output" == *"Deleted"* ]]
}

@test "unlock decrypts to directory" {
  # Create a valid tar.gz to simulate encrypted content
  mkdir -p "$TEST_DIR/src"
  echo "content" > "$TEST_DIR/src/data.txt"
  tar cz -C "$TEST_DIR" src > "$TEST_DIR/src.age"

  run bash -c "printf '%s\n' '$TEST_DIR/out' | bash '$SCRIPT_DIR/vault.sh' unlock '$TEST_DIR/src.age'"
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/out/src/data.txt" ]
  [[ "$output" == *"Decrypted"* ]]
}
