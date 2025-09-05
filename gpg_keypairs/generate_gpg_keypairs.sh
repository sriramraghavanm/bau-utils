#!/bin/bash

# Script to generate GPG key pairs for a project and environment
# Usage: ./generate_gpg_keypairs.sh <project_name> <env> <email> <passkey>

set -euo pipefail

error_exit() {
  echo "Error: $1" >&2
  exit 1
}

if [ $# -ne 4 ]; then
  echo "Usage: $0 <project_name> <env> <email> <passkey>"
  exit 1
fi

PROJECT_NAME="$1"
ENV="$2"
EMAIL="$3"
PASSKEY="$4"

# Validate email format (simple check)
if ! [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
  error_exit "Invalid email address: $EMAIL"
fi

if [ -z "$PASSKEY" ]; then
  error_exit "Passkey cannot be empty"
fi

GPG_DIR="$HOME/.gnupg/$ENV/$PROJECT_NAME"
EXPORT_DIR="$GPG_DIR/key-pair"

mkdir -p "$EXPORT_DIR" || error_exit "Failed to create directory: $EXPORT_DIR"

KEYGEN_FILE=$(mktemp)
trap 'rm -f "$KEYGEN_FILE"' EXIT

cat > "$KEYGEN_FILE" <<EOF
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: $PROJECT_NAME
Name-Comment: $ENV
Name-Email: $EMAIL
Expire-Date: 3y
%commit
EOF

echo "Generating GPG key (no pop-up should appear)..."

gpg --batch \
    --homedir "$GPG_DIR" \
    --pinentry-mode loopback \
    --passphrase "$PASSKEY" \
    --generate-key "$KEYGEN_FILE" || error_exit "GPG key generation failed"

echo "Exporting public and private keys..."
gpg --homedir "$GPG_DIR" --armor --export "$EMAIL" > "$EXPORT_DIR/public-key.asc" || error_exit "Failed to export public key"
gpg --homedir "$GPG_DIR" --armor --pinentry-mode loopback --passphrase "$PASSKEY" --export-secret-keys "$EMAIL" > "$EXPORT_DIR/private-key.asc" || error_exit "Failed to export private key"

echo "Key pair generated and exported to: $EXPORT_DIR"
echo "Public key: $EXPORT_DIR/public-key.asc"
echo "Private key: $EXPORT_DIR/private-key.asc"