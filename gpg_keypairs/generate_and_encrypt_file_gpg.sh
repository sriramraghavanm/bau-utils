#!/bin/bash

# Script to generate GPG key pairs for a project and environment, then encrypt an input file to <input_file>.gpg using the generated key.
# Usage:
#   ./generate_and_encrypt_file_gpg.sh <project_name> <env> <email> <passkey> <input_file> [OVERWRITE]
#
# Examples:
#   ./generate_and_encrypt_file_gpg.sh myproj prod user@example.com "StrongPass123!" ./store.csv
#   ./generate_and_encrypt_file_gpg.sh myproj prod user@example.com "StrongPass123!" ./store.csv 1   # allow overwrite
#
# Notes and best practices:
# - Non-interactive key generation via --batch and --pinentry-mode loopback.
# - Keys are scoped per project and environment under ~/.gnupg/<env>/<project_name>.
# - RSA-4096 keys (primary and subkey) for stronger security. Default expiry 3y; adjust as needed.
# - Validates email, passkey presence, input file, and prevents clobbering unless explicitly allowed via OVERWRITE=1.
# - Exports ASCII-armored public/private keys for portability. Handle private-key file securely.

set -euo pipefail

error_exit() {
  echo "Error: $1" >&2
  exit 1
}

info() { echo "Info: $*"; }
warn() { echo "Warning: $*"; }

if [ $# -lt 5 ] || [ $# -gt 6 ]; then
  echo "Usage: $0 <project_name> <env> <email> <passkey> <input_file> [OVERWRITE]"
  echo "  OVERWRITE: optional flag set to '1' to overwrite existing output file (<input_file>.gpg)"
  exit 1
fi

PROJECT_NAME="$1"
ENV="$2"
EMAIL="$3"
PASSKEY="$4"
INPUT_FILE="$5"
OVERWRITE="${6:-0}"

# Validate email format (simple check)
if ! [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  error_exit "Invalid email address: $EMAIL"
fi

if [ -z "$PASSKEY" ]; then
  error_exit "Passkey cannot be empty"
fi

# Validate input file
if [ ! -f "$INPUT_FILE" ]; then
  error_exit "Input file not found: $INPUT_FILE"
fi

# Derive output file as <input_file>.gpg
OUTPUT_FILE="${INPUT_FILE}.gpg"

# Prevent accidental overwrite
if [ -e "$OUTPUT_FILE" ] && [ "$OVERWRITE" != "1" ]; then
  error_exit "Output file already exists: $OUTPUT_FILE. Provide OVERWRITE=1 to overwrite."
fi

# Prepare dirs
GPG_DIR="$HOME/.gnupg/$ENV/$PROJECT_NAME"
EXPORT_DIR="$GPG_DIR/key-pair"

mkdir -p "$EXPORT_DIR" || error_exit "Failed to create directory: $EXPORT_DIR"
chmod 700 "$GPG_DIR" || true

# Correct variable assignment
KEYGEN_FILE=$(mktemp)
trap 'rm -f "$KEYGEN_FILE"' EXIT

# Stronger key settings: RSA 4096 for primary and subkey
cat > "$KEYGEN_FILE" <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $PROJECT_NAME
Name-Comment: $ENV
Name-Email: $EMAIL
Expire-Date: 3y
%commit
EOF

# Check for existing public key for this email to avoid duplicate keys
HAS_KEY=0
if gpg --homedir "$GPG_DIR" --list-keys --with-colons "$EMAIL" >/dev/null 2>&1; then
  HAS_KEY=1
fi

echo "Generating GPG key (non-interactive)..."
if [ "$HAS_KEY" -eq 1 ]; then
  warn "A key for '$EMAIL' already exists in $GPG_DIR. Skipping key generation and reusing existing key."
else
  gpg --batch \
      --homedir "$GPG_DIR" \
      --pinentry-mode loopback \
      --passphrase "$PASSKEY" \
      --generate-key "$KEYGEN_FILE" || error_exit "GPG key generation failed"
  info "Key generated for $EMAIL in $GPG_DIR"
fi

echo "Exporting public and private keys..."
gpg --homedir "$GPG_DIR" --armor --export "$EMAIL" > "$EXPORT_DIR/public-key.asc" || error_exit "Failed to export public key"
gpg --homedir "$GPG_DIR" --armor --pinentry-mode loopback --passphrase "$PASSKEY" --export-secret-keys "$EMAIL" > "$EXPORT_DIR/private-key.asc" || error_exit "Failed to export private key"

echo "Keys exported:"
echo "  Public key:  $EXPORT_DIR/public-key.asc"
echo "  Private key: $EXPORT_DIR/private-key.asc"
warn "Handle the private key securely. Do not commit or share it."

# Encrypt the input file to the derived output .gpg
echo "Encrypting '$INPUT_FILE' -> '$OUTPUT_FILE' for recipient '$EMAIL'..."
gpg --batch --yes \
    --homedir "$GPG_DIR" \
    --encrypt -r "$EMAIL" \
    -o "$OUTPUT_FILE" \
    "$INPUT_FILE" || error_exit "File encryption failed"

info "Encryption succeeded: $OUTPUT_FILE"

# Optional: show a brief summary of the key
if gpg --homedir "$GPG_DIR" --list-keys "$EMAIL" >/dev/null 2>&1; then
  echo "Key summary:"
  gpg --homedir "$GPG_DIR" --list-keys "$EMAIL"
fi

echo "Done."