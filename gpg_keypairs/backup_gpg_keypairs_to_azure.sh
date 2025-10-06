#!/bin/bash

# Script to backup selected GPG keypair directory to Azure Blob Storage.
# Usage: ./backup_gpg_keypairs_to_azure.sh
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

BASE_GPG_DIR="$HOME/.gnupg"

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

if ! command -v az &>/dev/null; then
    error_exit "'az' CLI is required. Please install Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli"
fi

if [ ! -d "$BASE_GPG_DIR" ]; then
    error_exit "GPG directory '$BASE_GPG_DIR' does not exist."
fi

if [ -z "${STORAGE_ACCOUNT:-}" ] || [ -z "${STORAGE_KEY:-}" ] || [ -z "${CONTAINER:-}" ]; then
    error_exit "Missing STORAGE_ACCOUNT, STORAGE_KEY or CONTAINER. Check $CONFIG_FILE or set defaults in the script."
fi

# List all GPG keypair directories and let user select one for backup
mapfile -t gpg_dirs < <(find "$BASE_GPG_DIR" -mindepth 2 -maxdepth 2 -type d)
declare -A keypair_map
idx=1

echo "Scanning for GPG keypair directories in: $BASE_GPG_DIR"
echo

for gpgdir in "${gpg_dirs[@]}"; do
    # Display all files in the directory
    env_name=$(basename "$(dirname "$gpgdir")")
    project_name=$(basename "$gpgdir")

    # List key files for info
    key_files=$(find "$gpgdir" -type f | sed "s|$gpgdir/|    |")
    echo "$idx) Environment: $env_name"
    echo "   Project: $project_name"
    echo "   GPG Key Directory: $gpgdir"
    echo "   Key Files:"
    echo "$key_files"
    echo "----------------------------------------------------"
    keypair_map["$idx"]="$gpgdir"
    ((idx++))
done

if [ ${#keypair_map[@]} -eq 0 ]; then
    error_exit "No GPG keypair directories found in $BASE_GPG_DIR."
fi

echo "Enter the number of the GPG keypair directory you want to back up:"
read -r selection
selection=$(echo "$selection" | xargs)
gpgdir="${keypair_map[$selection]:-}"

if [ -z "$gpgdir" ]; then
    error_exit "Invalid selection: $selection"
fi

env_name=$(basename "$(dirname "$gpgdir")")
project_name=$(basename "$gpgdir")

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

BLOB_PATH="$env_name/$project_name"

echo "Uploading GPG keypair directory files to Azure Blob Storage..."

find "$gpgdir" -type f | while read -r file; do
    relpath="${file#$gpgdir/}"
    blobname="$BLOB_PATH/$relpath"
    echo "  Uploading $file to $blobname ..."
    az storage blob upload \
        --account-name "$STORAGE_ACCOUNT" \
        --account-key "$STORAGE_KEY" \
        --container-name "$CONTAINER" \
        --name "$blobname" \
        --file "$file" \
        --overwrite true \
        &>/dev/null || error_exit "Failed to upload $file."
done

echo "GPG keypair directory successfully backed up to Azure Blob Storage under:"
echo "  https://$STORAGE_ACCOUNT.blob.core.windows.net/$CONTAINER/$BLOB_PATH/"