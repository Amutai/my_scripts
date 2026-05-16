# vault.sh

Encrypt and decrypt files or directories using [age](https://github.com/FiloSottile/age) (AES-256, passphrase-based).

## Why I Built This

I needed a simple, portable way to encrypt sensitive files (SSH keys, credentials, configs) before storing them on cloud drives or USB sticks. Existing tools were either too complex (GPG) or required key management I didn't want. `age` provides modern encryption with just a passphrase — this script wraps it with directory support, interactive prompts, and auto-installation so I can use it on any fresh Linux machine in seconds.

## Quick Start

```bash
# Encrypt a file
./vault.sh lock secrets.txt

# Encrypt a directory
./vault.sh lock my_creds/

# Decrypt
./vault.sh unlock secrets.txt.age
```

## Requirements

- Linux (Debian/Ubuntu, Fedora, Arch, or any with curl)
- `age` — the script auto-installs it if missing

## Usage

```
./vault.sh {lock|unlock} [path]
```

| Command | Description |
|---------|-------------|
| `lock [file/dir]` | Encrypt a file or directory. Prompts for output name and optional deletion of original. |
| `unlock [file.age]` | Decrypt a `.age` file. Prompts for extraction directory. |

If `[path]` is omitted, the script prompts interactively.

## How It Works

- **lock**: compresses the target with `tar` + `gzip`, then encrypts with `age` using a passphrase you provide. Output is a single `.age` file.
- **unlock**: decrypts the `.age` file and extracts the original contents into a directory.

## Security Notes

- Encryption: AES-256 via age's scrypt KDF (N=2^18)
- The `.age` file is safe to store on cloud, USB, git, or email — it's unreadable without the passphrase
- **Remember your passphrase** — there is no recovery mechanism
- After locking, consider `shred`-ing the original if on HDD (`shred -u file`). On SSD, `rm` is sufficient since TRIM handles it.

## Recovering on a New Machine

The `.age` file is fully portable. On any Linux machine:

```bash
# Get age (single binary, no dependencies)
curl -sL https://github.com/FiloSottile/age/releases/download/v1.2.0/age-v1.2.0-linux-amd64.tar.gz | tar xz
./age/age -d my_backup.age | tar xz
```

Or just run `./vault.sh unlock my_backup.age` — it will install `age` for you.

## File Listing

```
.
├── vault.sh          # The encryption script
├── VAULT_README.md   # This file
└── *.age             # Encrypted archives (safe to share/store anywhere)
```
