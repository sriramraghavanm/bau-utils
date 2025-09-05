#!/bin/bash

set -euo pipefail

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

BASE_GPG_DIR="${1:-$HOME/.gnupg}"

if [ ! -d "$BASE_GPG_DIR" ]; then
    error_exit "GPG directory '$BASE_GPG_DIR' does not exist."
fi

echo "Scanning for GPG key pairs in: $BASE_GPG_DIR"
echo

found_any=0

# Gather all homedirs into an array
mapfile -t homedirs < <(find "$BASE_GPG_DIR" -mindepth 2 -maxdepth 2 -type d)

for homedir in "${homedirs[@]}"; do
    if [ ! -d "$homedir" ]; then
        continue
    fi

    key_list=$(gpg --homedir "$homedir" --list-keys --with-colons 2>/dev/null || true)
    secret_list=$(gpg --homedir "$homedir" --list-secret-keys --with-colons 2>/dev/null || true)

    if [ -n "$key_list" ] || [ -n "$secret_list" ]; then
        found_any=1
        env_name=$(basename "$(dirname "$homedir")")
        project_name=$(basename "$homedir")

        echo "Environment: $env_name"
        echo "Project: $project_name"
        echo "GPG Homedir: $homedir"

        if [ -n "$key_list" ]; then
            echo "  Public Keys:"
            echo "$key_list" | grep '^uid:' | cut -d: -f10 | while read -r uid; do
                echo "    - $uid"
            done
        else
            echo "  No public keys found."
        fi

        if [ -n "$secret_list" ]; then
            echo "  Private Keys:"
            echo "$secret_list" | grep '^uid:' | cut -d: -f10 | while read -r uid; do
                echo "    - $uid"
            done
        else
            echo "  No private keys found."
        fi

        echo "----------------------------------------------------"
    fi
done

if [ "$found_any" -eq 0 ]; then
    echo "No GPG key pairs found in $BASE_GPG_DIR."
fi