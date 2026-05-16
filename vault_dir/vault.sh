#!/bin/bash
# vault.sh — encrypt/decrypt files/directories using age
# Checks for age installation, installs on Linux if missing

set -euo pipefail

AGE_VERSION="1.2.0"

install_age() {
  echo "age not found. Attempting install..."
  if [[ ! -f /etc/os-release ]]; then
    echo "Error: Not a supported Linux system. Install age manually:"
    echo "  https://github.com/FiloSottile/age/releases"
    exit 1
  fi

  source /etc/os-release
  case "$ID" in
    ubuntu|debian|pop|mint)
      sudo apt-get update -qq && sudo apt-get install -y -qq age ;;
    fedora)
      sudo dnf install -y age ;;
    arch|manjaro)
      sudo pacman -S --noconfirm age ;;
    *)
      echo "Unsupported distro ($ID). Installing from GitHub release..."
      local url="https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz"
      curl -sL "$url" | sudo tar xz -C /usr/local/bin --strip-components=1 age/age age/age-keygen
      ;;
  esac

  if ! command -v age &>/dev/null; then
    echo "Error: Installation failed."
    exit 1
  fi
  echo "age installed successfully."
}

check_age() {
  command -v age &>/dev/null || install_age
}

prompt_input() {
  local prompt="$1" default="$2" var
  if [[ -n "$default" ]]; then
    read -rp "$prompt [$default]: " var
    echo "${var:-$default}"
  else
    read -rp "$prompt: " var
    echo "$var"
  fi
}

do_lock() {
  local source="${1:-}"
  if [[ -z "$source" ]]; then
    source=$(prompt_input "Path to file/directory to encrypt" "")
  fi

  # Strip trailing slash
  source="${source%/}"

  if [[ ! -e "$source" ]]; then
    echo "Error: '$source' not found."
    exit 1
  fi

  local default_out="$(basename "$source").age"
  local output
  output=$(prompt_input "Output encrypted file name" "$default_out")

  if [[ -f "$output" ]]; then
    read -rp "'$output' exists. Overwrite? [y/N]: " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || exit 0
  fi

  tar cz "$source" | age -p > "$output"
  echo "Encrypted → $output"

  read -rp "Delete original '$source'? [y/N]: " del
  if [[ "$del" =~ ^[Yy]$ ]]; then
    rm -rf "$source"
    echo "Deleted '$source'."
  fi
}

do_unlock() {
  local source="${1:-}"
  if [[ -z "$source" ]]; then
    source=$(prompt_input "Path to encrypted .age file" "")
  fi

  if [[ ! -f "$source" ]]; then
    echo "Error: '$source' not found."
    exit 1
  fi

  local default_dir
  default_dir=$(basename "$source" .age)
  local output
  output=$(prompt_input "Extract to directory" "$default_dir")

  mkdir -p "$output"
  age -d "$source" | tar xz -C "$output"
  echo "Decrypted → $output/"
}

usage() {
  echo "Usage: $0 {lock|unlock} [path]"
  echo ""
  echo "  lock   [file/dir]   Encrypt a file or directory"
  echo "  unlock [file.age]   Decrypt an .age file"
}

check_age

case "${1:-}" in
  lock)   do_lock "${2:-}" ;;
  unlock) do_unlock "${2:-}" ;;
  *)      usage ;;
esac
