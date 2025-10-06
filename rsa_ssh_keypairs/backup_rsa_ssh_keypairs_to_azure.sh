#!/bin/bash

# Script to backup selected RSA SSH key pair to Azure Blob Storage.
# Usage: ./backup_rsa_ssh_keypairs_to_azure.sh
# Optional config file: ./backup.conf

set -euo pipefail

CONFIG_FILE="./backup.conf"

# Default values (can be overridden in backup.conf)
STORAGE_ACCOUNT="your-storage-account"
STORAGE_KEY="your-storage-key"
CONTAINER="your-container"

# Load config file if present
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

BASE_SSH_DIR="$HOME/.ssh"

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

if ! command -v az &>/dev/null; then
    error_exit "'az' CLI is required. Please install Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli"
fi

if [ ! -d "$BASE_SSH_DIR" ]; then
    error_exit "SSH directory '$BASE_SSH_DIR' does not exist."
fi

if [ -z "${STORAGE_ACCOUNT:-}" ] || [ -z "${STORAGE_KEY:-}" ] || [ -z "${CONTAINER:-}" ]; then
    error_exit "Missing STORAGE_ACCOUNT, STORAGE_KEY or CONTAINER. Check $CONFIG_FILE or set defaults in the script."
fi

# List all key pairs and let user select one for backup
mapfile -t ssh_dirs < <(find "$BASE_SSH_DIR" -mindepth 2 -maxdepth 2 -type d)
declare -A keypair_map
idx=1

echo "Scanning for RSA SSH key pairs in: $BASE_SSH_DIR"
echo

for sshdir in "${ssh_dirs[@]}"; do
    keyfile="$sshdir/key-pair/id_rsa"
    pubfile="$sshdir/key-pair/id_rsa.pub"

    if [ -f "$keyfile" ] && [ -f "$pubfile" ]; then
        env_name=$(basename "$(dirname "$sshdir")")
        project_name=$(basename "$sshdir")
        echo "$idx) Environment: $env_name"
        echo "   Project: $project_name"
        echo "   SSH Key Directory: $sshdir/key-pair"
        echo "     Private Key: $keyfile"
        echo "     Public Key:  $pubfile"
        echo "----------------------------------------------------"
        keypair_map["$idx"]="$sshdir"
        ((idx++))
    fi
done

if [ ${#keypair_map[@]} -eq 0 ]; then
    error_exit "No RSA SSH key pairs found in $BASE_SSH_DIR."
fi

echo "Enter the number of the key pair you want to back up:"
read -r selection
selection=$(echo "$selection" | xargs)
sshdir="${keypair_map[$selection]:-}"

if [ -z "$sshdir" ]; then
    error_exit "Invalid selection: $selection"
fi

KEYPAIR_DIR="$sshdir/key-pair"
PRIVATE_KEY="$KEYPAIR_DIR/id_rsa"
PUBLIC_KEY="$KEYPAIR_DIR/id_rsa.pub"
env_name=$(basename "$(dirname "$sshdir")")
project_name=$(basename "$sshdir")

# Check container access and create if missing
echo "Checking container access..."
container_exists=$(az storage container exists \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --name "$CONTAINER" \
    --query "exists" \
    --output tsv)

if [ "$container_exists" != "true" ]; then
    echo "Container '$CONTAINER' does not exist. Creating it..."
    az storage container create \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --name "$CONTAINER" \
        &>/dev/null || error_exit "Failed to create container '$CONTAINER'."
    echo "Container '$CONTAINER' created."
fi

BLOB_PATH="$env_name/$project_name/key-pair"

echo "Uploading private key..."
az storage blob upload \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --container-name "$CONTAINER" \
    --name "$BLOB_PATH/id_rsa" \
    --file "$PRIVATE_KEY" \
    --overwrite true \
    &>/dev/null || error_exit "Failed to upload private key."

echo "Uploading public key..."
az storage blob upload \
    --account-name "$STORAGE_ACCOUNT" \
    --account-key "$STORAGE_KEY" \
    --container-name "$CONTAINER" \
    --name "$BLOB_PATH/id_rsa.pub" \
    --file "$PUBLIC_KEY" \
    --overwrite true \
    &>/dev/null || error_exit "Failed to upload public key."

echo "RSA SSH key pair successfully backed up to Azure Blob Storage at:"
echo "  https://$STORAGE_ACCOUNT.blob.core.windows.net/$CONTAINER/$BLOB_PATH/id_rsa"
echo "  https://$STORAGE_ACCOUNT.blob.core.windows.net/$CONTAINER/$BLOB_PATH/id_rsa.pub"