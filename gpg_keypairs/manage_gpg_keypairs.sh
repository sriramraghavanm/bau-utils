#!/bin/bash

# Script to list and optionally delete GPG key pairs for each environment and project
# Usage: ./manage_gpg_keypairs.sh [base_gpg_dir]
# Default GPG directory is $HOME/.gnupg

set -euo pipefail

error_exit() {
    echo "Error: $1" >&2
    exit 1
}

BASE_GPG_DIR="${1:-$HOME/.gnupg}"

if [ ! -d "$BASE_GPG_DIR" ]; then
    error_exit "GPG directory '$BASE_GPG_DIR' does not exist."
fi

list_keypairs() {
    local gpg_dirs=()
    mapfile -t gpg_dirs < <(find "$BASE_GPG_DIR" -mindepth 2 -maxdepth 2 -type d)
    local idx=1
    declare -gA keypair_map
    keypair_map=()

    echo "Scanning for GPG key pairs in: $BASE_GPG_DIR"
    echo

    for homedir in "${gpg_dirs[@]}"; do
        key_list=$(gpg --homedir "$homedir" --list-keys --with-colons 2>/dev/null || true)
        secret_list=$(gpg --homedir "$homedir" --list-secret-keys --with-colons 2>/dev/null || true)

        if [ -n "$key_list" ] || [ -n "$secret_list" ]; then
            env_name=$(basename "$(dirname "$homedir")")
            project_name=$(basename "$homedir")
            echo "$idx) Environment: $env_name"
            echo "   Project: $project_name"
            echo "   GPG Homedir: $homedir"

            pub_uids=($(echo "$key_list" | grep '^uid:' | cut -d: -f10))
            sec_uids=($(echo "$secret_list" | grep '^uid:' | cut -d: -f10))

            echo "     Public Keys:"
            if [ "${#pub_uids[@]}" -gt 0 ]; then
                for uid in "${pub_uids[@]}"; do echo "       - $uid"; done
            else
                echo "       No public keys found."
            fi

            echo "     Private Keys:"
            if [ "${#sec_uids[@]}" -gt 0 ]; then
                for uid in "${sec_uids[@]}"; do echo "       - $uid"; done
            else
                echo "       No private keys found."
            fi

            echo "----------------------------------------------------"
            keypair_map["$idx"]="$homedir"
            ((idx++))
        fi
    done

    if [ ${#keypair_map[@]} -eq 0 ]; then
        echo "No GPG key pairs found in $BASE_GPG_DIR."
        return 1
    else
        return 0
    fi
}

delete_keypair() {
    local homedir="$1"
    read -p "Are you sure you want to delete all keys in '$homedir'? This CANNOT be undone. Type 'yes' to confirm: " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Deletion cancelled for $homedir."
        return
    fi

    # Delete keys and homedir
    key_list=$(gpg --homedir "$homedir" --list-keys --with-colons 2>/dev/null | grep '^pub:' | cut -d: -f5)
    secret_list=$(gpg --homedir "$homedir" --list-secret-keys --with-colons 2>/dev/null | grep '^sec:' | cut -d: -f5)

    for keyid in $key_list; do
        gpg --homedir "$homedir" --batch --yes --delete-keys "$keyid" 2>/dev/null || true
    done
    for keyid in $secret_list; do
        gpg --homedir "$homedir" --batch --yes --delete-secret-keys "$keyid" 2>/dev/null || true
    done

    # Remove the directory safely (if empty)
    rm -rf "$homedir"
    echo "Deleted GPG key pair and homedir: $homedir"
}

while true; do
    if ! list_keypairs; then
        break
    fi

    echo "Enter the numbers of the key pairs you want to delete, separated by spaces (or press Enter to skip):"
    read -r input

    # Remove spaces
    input=$(echo "$input" | xargs)

    if [ -z "$input" ]; then
        echo "No key pairs selected for deletion. Exiting."
        break
    fi

    for idx in $input; do
        homedir="${keypair_map[$idx]:-}"
        if [ -z "$homedir" ]; then
            echo "Invalid selection: $idx"
        else
            delete_keypair "$homedir"
        fi
    done

    echo
    echo "Updated list of GPG key pairs:"
    echo
done