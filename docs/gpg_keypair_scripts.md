# GPG Key Pair Utility Scripts

This documentation describes the usage and functionality of the GPG keypair management scripts found in the `gpg_keypairs` directory.

## Table of Contents

- [generate_gpg_keypairs.sh](#generate_gpg_keypairssh)
- [list_gpg_keypairs.sh](#list_gpg_keypairssh)
- [manage_gpg_keypairs.sh](#manage_gpg_keypairssh)

---

## `generate_gpg_keypairs.sh`

### Overview
Generates GPG key pairs for a specific project and environment. Validates input, creates a dedicated GPG home directory, and exports both public and private keys.

### Usage
```bash
./generate_gpg_keypairs.sh <project_name> <env> <email> <passkey>
```
- `<project_name>`: Name of the project.
- `<env>`: Environment name (e.g., `dev`, `prod`).
- `<email>`: Email address for the GPG key (validated).
- `<passkey>`: Passphrase for the GPG key.

### Features
- Creates a unique GPG home directory for the specified project/environment.
- Automatically validates email format and passkey presence.
- Generates a 2048-bit RSA GPG key with a 3-year expiry.
- Exports public/private keys to `key-pair` subdirectory inside the GPG home.

### Outputs
- Public key: `key-pair/public-key.asc`
- Private key: `key-pair/private-key.asc`

### Example
```bash
./generate_gpg_keypairs.sh myproject dev user@example.com mysecurepass
```

### Error Handling
- Invalid argument count, email format, or missing passkey will abort the script with a relevant error message.

### Notes
- No GUI popups should appear during key generation.
- Keys are stored in `$HOME/.gnupg/<env>/<project_name>/key-pair/`.

---

## `list_gpg_keypairs.sh`

### Overview
Lists all GPG key pairs stored under a specified GPG directory (default: `$HOME/.gnupg`). Shows both public and private keys for each project/environment.

### Usage
```bash
./list_gpg_keypairs.sh [base_gpg_dir]
```
- `[base_gpg_dir]` (optional): Root directory to scan for GPG key pairs. Defaults to `$HOME/.gnupg`.

### Features
- Recursively scans for GPG home directories two levels deep.
- For each found project/environment, displays:
  - Environment name
  - Project name
  - GPG home directory path
  - Associated public and private keys (user IDs)

### Output Example
```
Environment: dev
Project: myproject
GPG Homedir: /home/user/.gnupg/dev/myproject
  Public Keys:
    - user@example.com
  Private Keys:
    - user@example.com
----------------------------------------------------
```

### Error Handling
- If the specified directory does not exist, the script aborts with an error.
- If no key pairs are found, a message is displayed.

### Notes
- The script is read-only; does not modify any keys.

---

## `manage_gpg_keypairs.sh`

### Overview
Lists and optionally deletes GPG key pairs for each environment and project found in a specified GPG directory (default: `$HOME/.gnupg`). Provides an interactive interface for batch deletion.

### Usage
```bash
./manage_gpg_keypairs.sh [base_gpg_dir]
```
- `[base_gpg_dir]` (optional): Root directory to scan for GPG key pairs. Defaults to `$HOME/.gnupg`.

### Features
- Lists all GPG key pairs grouped by environment/project.
- Displays:
  - Index number
  - Environment
  - Project
  - GPG home directory path
  - Associated public and private keys (user IDs)
- Interactive prompt for selecting key pairs to delete by index.
- Deletion requires explicit confirmation (`"yes"`).
- Safely removes GPG keys and their directories.

### Output Example
```
1) Environment: dev
   Project: myproject
   GPG Homedir: /home/user/.gnupg/dev/myproject
     Public Keys:
       - user@example.com
     Private Keys:
       - user@example.com
----------------------------------------------------
Enter the numbers of the key pairs you want to delete, separated by spaces (or press Enter to skip):
```

### Error Handling
- If the specified directory does not exist, the script aborts.
- Invalid selection indices are ignored with a warning.
- Deletion is only performed after user confirmation.

### Notes
- Deletion is permanent and cannot be undone.
- After deletions, the script refreshes and displays the remaining key pairs.

---