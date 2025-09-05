#!/bin/bash

# Script to generate RSA SSH key pair in PEM format for a project and environment
# Usage: ./generate_rsa_ssh_keypairs.sh <project_name> <env> <passkey>

set -euo pipefail

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

if [ $# -ne 3 ]; then
    echo "Usage: $0 <project_name> <env> <passkey>"
    exit 1
fi

PROJECT_NAME="$1"
ENV="$2"
PASSKEY="$3"

if [ -z "$PASSKEY" ]; then
    error_exit "Passkey cannot be empty"
fi

SSH_DIR="$HOME/.ssh/$ENV/$PROJECT_NAME"
EXPORT_DIR="$SSH_DIR/key-pair"

mkdir -p "$EXPORT_DIR" || error_exit "Failed to create directory: $EXPORT_DIR"

KEYFILE="$EXPORT_DIR/id_rsa"
PUBFILE="$EXPORT_DIR/id_rsa.pub"

echo "Generating RSA SSH key pair in PEM format..."

ssh-keygen -t rsa -b 4096 -m PEM -o -a 100 -f "$KEYFILE" -N "$PASSKEY" < /dev/null || error_exit "SSH key generation failed"

echo "Key pair generated:"
echo "  Private key: $KEYFILE"
echo "  Public key:  $PUBFILE"
