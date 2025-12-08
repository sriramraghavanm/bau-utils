# Script Documentation

Detailed documentation for each script in the GPG Keypair Management Utilities toolkit.

## Table of Contents

1. [generate_gpg_keypairs.sh](#generate_gpg_keypairssh)
2. [generate_and_encrypt_file_gpg.sh](#generate_and_encrypt_file_gpgsh)
3. [list_gpg_keypairs.sh](#list_gpg_keypairssh)
4. [manage_gpg_keypairs.sh](#manage_gpg_keypairssh)
5. [backup_gpg_keypairs_to_azure.sh](#backup_gpg_keypairs_to_azuresh)

---

## generate_gpg_keypairs.sh

### Purpose
Generates RSA-2048 GPG keypairs for a specific project and environment in non-interactive batch mode.

### Synopsis
```bash
./generate_gpg_keypairs.sh <project_name> <env> <email> <passkey>
```

### Parameters

| Parameter | Required | Description | Validation |
|-----------|----------|-------------|------------|
| `project_name` | Yes | Project identifier | Any string (alphanumeric recommended) |
| `env` | Yes | Environment name | Any string (dev/staging/prod recommended) |
| `email` | Yes | Email address for the key | Must match email regex pattern |
| `passkey` | Yes | Passphrase for private key | Non-empty string (16+ chars recommended) |

### Key Specifications

| Property | Value |
|----------|-------|
| Algorithm | RSA |
| Key Length | 2048 bits |
| Subkey Type | RSA |
| Subkey Length | 2048 bits |
| Expiration | 3 years |

### Output Location

**Keys are stored in:**
```
~/.gnupg/<env>/<project_name>/key-pair/
├── public-key.asc   # ASCII-armored public key
└── private-key.asc  # ASCII-armored private key
```

**Other files created:**
```
~/.gnupg/<env>/<project_name>/
├── pubring.kbx            # Public keyring database
├── trustdb.gpg            # Trust database
└── private-keys-v1.d/     # Private key storage directory
```

### Examples

**Basic usage:**
```bash
./generate_gpg_keypairs.sh myapp prod admin@example.com "SecurePass123!"
```

**Multiple environments:**
```bash
# Development environment
./generate_gpg_keypairs.sh api-service dev dev@company.com "DevPass456!"

# Staging environment
./generate_gpg_keypairs.sh api-service staging staging@company.com "StagingPass789!"

# Production environment
./generate_gpg_keypairs.sh api-service prod security@company.com "ProdPass000!"
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Invalid arguments (wrong number of parameters) |
| 1 | Invalid email format |
| 1 | Empty passkey |
| 1 | Directory creation failed |
| 1 | GPG key generation failed |
| 1 | Key export failed |

### Error Handling

**Invalid email:**
```bash
$ ./generate_gpg_keypairs.sh myapp prod invalid-email "pass"
Error: Invalid email address: invalid-email
```

**Empty passkey:**
```bash
$ ./generate_gpg_keypairs.sh myapp prod user@example.com ""
Error: Passkey cannot be empty
```

**GPG failure:**
```bash
Error: GPG key generation failed
```

### Security Considerations

1. **Passphrase visible in process list** - Use with caution in multi-user systems
2. **Private key on disk** - Ensure proper file permissions (600)
3. **Key expiration** - Keys expire in 3 years (configurable in script)
4. **Directory permissions** - Script sets GPG dir to 700

### Implementation Details

**Key generation parameters:**
```bash
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: $PROJECT_NAME
Name-Comment: $ENV
Name-Email: $EMAIL
Expire-Date: 3y
```

**GPG invocation:**
```bash
gpg --batch \
    --homedir "$GPG_DIR" \
    --pinentry-mode loopback \
    --passphrase "$PASSKEY" \
    --generate-key "$KEYGEN_FILE"
```

### Customization

**To change key length to 4096 bits:**
Edit lines 38-41:
```bash
Key-Type: RSA
Key-Length: 4096        # Changed from 2048
Subkey-Type: RSA
Subkey-Length: 4096     # Changed from 2048
```

**To change expiration:**
Edit line 45:
```bash
Expire-Date: 5y  # Changed from 3y (or use 0 for no expiration)
```

---

## generate_and_encrypt_file_gpg.sh

### Purpose
Generates RSA-4096 GPG keypairs (or reuses existing) and encrypts a specified input file to `<input_file>.gpg`.

### Synopsis
```bash
./generate_and_encrypt_file_gpg.sh <project_name> <env> <email> <passkey> <input_file> [OVERWRITE]
```

### Parameters

| Parameter | Required | Description | Validation |
|-----------|----------|-------------|------------|
| `project_name` | Yes | Project identifier | Any string |
| `env` | Yes | Environment name | Any string |
| `email` | Yes | Email for the key | Must match email regex |
| `passkey` | Yes | Passphrase | Non-empty string |
| `input_file` | Yes | File to encrypt | Must exist |
| `OVERWRITE` | No | Overwrite flag (1 to allow) | 0 or 1 (default: 0) |

### Key Specifications

| Property | Value |
|----------|-------|
| Algorithm | RSA |
| Key Length | **4096 bits** (stronger than basic generation) |
| Subkey Type | RSA |
| Subkey Length | 4096 bits |
| Expiration | 3 years |

### Output

**Encrypted file:**
```
<input_file>.gpg
```

**Example:**
- Input: `data.csv`
- Output: `data.csv.gpg`

### Examples

**Encrypt a CSV file:**
```bash
./generate_and_encrypt_file_gpg.sh myapp prod admin@example.com "Pass123!" ./data.csv
```

**Encrypt with overwrite:**
```bash
./generate_and_encrypt_file_gpg.sh myapp prod admin@example.com "Pass123!" ./data.csv 1
```

**Encrypt multiple files:**
```bash
for file in *.csv; do
  ./generate_and_encrypt_file_gpg.sh myapp prod admin@example.com "Pass123!" "$file" 1
done
```

**Encrypt JSON configuration:**
```bash
./generate_and_encrypt_file_gpg.sh api prod sec@company.com "SecPass!" ./config.json
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Invalid arguments |
| 1 | Invalid email format |
| 1 | Empty passkey |
| 1 | Input file not found |
| 1 | Output file exists (without OVERWRITE=1) |
| 1 | Directory creation failed |
| 1 | GPG key generation failed |
| 1 | Key export failed |
| 1 | File encryption failed |

### Error Handling

**Input file not found:**
```bash
$ ./generate_and_encrypt_file_gpg.sh myapp prod user@example.com "pass" missing.csv
Error: Input file not found: missing.csv
```

**Output file already exists:**
```bash
$ ./generate_and_encrypt_file_gpg.sh myapp prod user@example.com "pass" data.csv
Error: Output file already exists: data.csv.gpg. Provide OVERWRITE=1 to overwrite.
```

**Key already exists (warning, not error):**
```bash
Warning: A key for 'user@example.com' already exists in ~/.gnupg/prod/myapp. 
Skipping key generation and reusing existing key.
```

### Features

✅ **Email validation** - Rejects invalid email formats  
✅ **File existence check** - Validates input file exists  
✅ **Overwrite protection** - Prevents accidental file overwrite  
✅ **Key reuse** - Reuses existing keys if present  
✅ **Stronger encryption** - RSA-4096 vs RSA-2048  
✅ **Security warnings** - Reminds to handle private key securely  

### Workflow

1. **Validate inputs** (email, passkey, input file)
2. **Check output file** (error if exists and OVERWRITE!=1)
3. **Create directories** (`~/.gnupg/<env>/<project>/key-pair/`)
4. **Check for existing key** for the email
5. **Generate key** if not exists, or **skip** if exists
6. **Export keys** (public and private)
7. **Encrypt file** to `<input_file>.gpg`
8. **Display summary** with warnings

### Decryption

**To decrypt the generated file:**
```bash
gpg --homedir ~/.gnupg/prod/myapp \
    --pinentry-mode loopback \
    --passphrase "Pass123!" \
    --decrypt data.csv.gpg > data.csv
```

**Or interactively:**
```bash
gpg --homedir ~/.gnupg/prod/myapp --decrypt data.csv.gpg > data.csv
# Enter passphrase when prompted
```

### Security Considerations

1. **Stronger keys** - 4096-bit RSA provides better security than 2048-bit
2. **Private key warning** - Script warns to handle private key securely
3. **Overwrite protection** - Prevents accidental data loss
4. **Batch mode** - Non-interactive for automation

### Customization

**To encrypt for multiple recipients:**
```bash
# Edit encryption command (around line 118)
gpg --batch --yes \
    --homedir "$GPG_DIR" \
    --encrypt -r "$EMAIL" \
    -r "recipient2@example.com" \
    -r "recipient3@example.com" \
    -o "$OUTPUT_FILE" \
    "$INPUT_FILE"
```

**To use different cipher algorithm:**
```bash
gpg --batch --yes \
    --homedir "$GPG_DIR" \
    --cipher-algo AES256 \
    --encrypt -r "$EMAIL" \
    -o "$OUTPUT_FILE" \
    "$INPUT_FILE"
```

---

## list_gpg_keypairs.sh

### Purpose
Scans and displays all GPG keypairs organized by environment and project with public/private key details.

### Synopsis
```bash
./list_gpg_keypairs.sh [base_gpg_dir]
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `base_gpg_dir` | No | `$HOME/.gnupg` | Base GPG directory to scan |

### Examples

**List all keypairs (default location):**
```bash
./list_gpg_keypairs.sh
```

**List keypairs in custom directory:**
```bash
./list_gpg_keypairs.sh /path/to/custom/gnupg
```

### Sample Output

```
Scanning for GPG key pairs in: /home/user/.gnupg

Environment: prod
Project: myapp
GPG Homedir: /home/user/.gnupg/prod/myapp
  Public Keys:
    - myapp (prod) <admin@example.com>
  Private Keys:
    - myapp (prod) <admin@example.com>
----------------------------------------------------
Environment: dev
Project: api-service
GPG Homedir: /home/user/.gnupg/dev/api-service
  Public Keys:
    - api-service (dev) <dev@example.com>
  Private Keys:
    - api-service (dev) <dev@example.com>
----------------------------------------------------
```

**When no keypairs found:**
```
Scanning for GPG key pairs in: /home/user/.gnupg

No GPG key pairs found in /home/user/.gnupg.
```

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (keypairs found) |
| 0 | Success (no keypairs found) |
| 1 | GPG directory doesn't exist |

### Implementation Details

**Directory scanning:**
```bash
# Finds all directories 2 levels deep (env/project structure)
find "$BASE_GPG_DIR" -mindepth 2 -maxdepth 2 -type d
```

**Key listing:**
```bash
# Public keys
gpg --homedir "$homedir" --list-keys --with-colons 2>/dev/null

# Private keys
gpg --homedir "$homedir" --list-secret-keys --with-colons 2>/dev/null
```

**UID extraction:**
```bash
# Extract user IDs from colon-separated output
echo "$key_list" | grep '^uid:' | cut -d: -f10
```

### Use Cases

1. **Inventory check** - See all available keypairs
2. **Pre-deletion review** - Check before using `manage_gpg_keypairs.sh`
3. **Pre-backup verification** - Verify keypairs before Azure backup
4. **Troubleshooting** - Confirm keys exist and are readable

### Troubleshooting

**No output:**
- Check if GPG directory exists: `ls -la ~/.gnupg`
- Verify directory structure: `find ~/.gnupg -type d`
- Generate a keypair to test: `./generate_gpg_keypairs.sh test dev test@example.com "pass"`

**Permission denied errors:**
```bash
# Fix permissions
chmod 700 ~/.gnupg
find ~/.gnupg -type d -exec chmod 700 {} \;
```

---

## manage_gpg_keypairs.sh

### Purpose
Interactive script to list and delete GPG keypairs with confirmation prompts for safe key management.

### Synopsis
```bash
./manage_gpg_keypairs.sh [base_gpg_dir]
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `base_gpg_dir` | No | `$HOME/.gnupg` | Base GPG directory to manage |

### Examples

**Manage keypairs (default location):**
```bash
./manage_gpg_keypairs.sh
```

**Manage keypairs in custom directory:**
```bash
./manage_gpg_keypairs.sh /path/to/custom/gnupg
```

### Interactive Workflow

1. **Displays numbered list** of all keypairs
2. **Prompts for selection** (space-separated numbers)
3. **Confirmation prompt** for each deletion (type `yes`)
4. **Deletes keys and homedir**
5. **Shows updated list**
6. **Loops until user presses Enter** without selection

### Sample Session

```
Scanning for GPG key pairs in: /home/user/.gnupg

1) Environment: prod
   Project: myapp
   GPG Homedir: /home/user/.gnupg/prod/myapp
     Public Keys:
       - myapp (prod) <admin@example.com>
     Private Keys:
       - myapp (prod) <admin@example.com>
----------------------------------------------------
2) Environment: dev
   Project: api-service
   GPG Homedir: /home/user/.gnupg/dev/api-service
     Public Keys:
       - api-service (dev) <dev@example.com>
     Private Keys:
       - api-service (dev) <dev@example.com>
----------------------------------------------------

Enter the numbers of the key pairs you want to delete, separated by spaces 
(or press Enter to skip):
1

Are you sure you want to delete all keys in '/home/user/.gnupg/prod/myapp'? 
This CANNOT be undone. Type 'yes' to confirm: yes
Deleted GPG key pair and homedir: /home/user/.gnupg/prod/myapp

Updated list of GPG key pairs:

1) Environment: dev
   Project: api-service
   GPG Homedir: /home/user/.gnupg/dev/api-service
     Public Keys:
       - api-service (dev) <dev@example.com>
     Private Keys:
       - api-service (dev) <dev@example.com>
----------------------------------------------------

Enter the numbers of the key pairs you want to delete, separated by spaces 
(or press Enter to skip):
[Press Enter to exit]

No key pairs selected for deletion. Exiting.
```

### Deletion Process

For each selected keypair:

1. **Confirmation prompt** - User must type `yes`
2. **Delete public keys** - Removes from keyring
3. **Delete private keys** - Removes from keyring
4. **Remove directory** - Deletes entire homedir (`rm -rf`)

### Safety Features

✅ **Explicit confirmation** - Must type `yes` (not just `y`)  
✅ **Cannot be undone warning** - Clear message before deletion  
✅ **Per-keypair confirmation** - Separate prompt for each  
✅ **Invalid selection handling** - Ignores invalid numbers  
✅ **Graceful cancellation** - Type anything other than `yes`  

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (with or without deletions) |
| 1 | GPG directory doesn't exist |

### Batch Deletion

**Delete multiple keypairs at once:**
```
Enter the numbers of the key pairs you want to delete:
1 3 5
```

**Cancel deletion:**
```
Are you sure you want to delete all keys in '...'? Type 'yes' to confirm: no
Deletion cancelled for ~/.gnupg/prod/myapp.
```

### Use Cases

1. **Cleanup old keys** - Remove development/test keys
2. **Environment decommission** - Delete all keys for decommissioned env
3. **Key rotation** - Delete old keys after rotation
4. **Error recovery** - Remove corrupted keypairs

### Best Practices

1. **Backup before deletion** - Use `backup_gpg_keypairs_to_azure.sh` first
2. **Verify selection** - Double-check numbers before confirming
3. **Document deletions** - Maintain key inventory
4. **Check dependencies** - Ensure no encrypted data depends on key

### Recovery

**Keys cannot be recovered after deletion**. If you need to restore:

1. **From Azure backup:**
   ```bash
   az storage blob download \
     --account-name mystorageaccount \
     --container-name key-pairs-backup \
     --name prod/myapp/key-pair/private-key.asc \
     --file /tmp/private-key.asc
   
   gpg --import /tmp/private-key.asc
   shred -u /tmp/private-key.asc
   ```

2. **Regenerate new keypair** (data encrypted with old key will be inaccessible)

---

## backup_gpg_keypairs_to_azure.sh

### Purpose
Backs up selected GPG keypair directory to Azure Blob Storage with automatic container creation and structured blob paths.

### Synopsis
```bash
./backup_gpg_keypairs_to_azure.sh
```

### Parameters

None (interactive selection)

### Configuration

**Required configuration file:** `backup.conf`

```bash
STORAGE_ACCOUNT="your-storage-account-name"
STORAGE_KEY="your-storage-account-key"
CONTAINER="key-pairs-backup"
```

**Or environment variables:**
```bash
export STORAGE_ACCOUNT="your-storage-account-name"
export STORAGE_KEY="your-storage-account-key"
export CONTAINER="key-pairs-backup"
```

### Prerequisites

1. **Azure CLI installed and authenticated**
   ```bash
   az login
   az account show
   ```

2. **Configuration file with valid credentials**
   ```bash
   cat backup.conf
   # Should contain STORAGE_ACCOUNT, STORAGE_KEY, CONTAINER
   ```

3. **At least one GPG keypair**
   ```bash
   ./list_gpg_keypairs.sh
   ```

### Interactive Workflow

1. **Scans GPG directory** for all keypairs
2. **Displays numbered list** with key files
3. **Prompts for selection** (single number)
4. **Verifies container exists** (creates if missing)
5. **Uploads all files** from selected directory
6. **Displays blob storage URL**

### Sample Session

```
Scanning for GPG keypair directories in: /home/user/.gnupg

1) Environment: prod
   Project: myapp
   GPG Key Directory: /home/user/.gnupg/prod/myapp
   Key Files:
    key-pair/private-key.asc
    key-pair/public-key.asc
    pubring.kbx
    trustdb.gpg
----------------------------------------------------
2) Environment: dev
   Project: api-service
   GPG Key Directory: /home/user/.gnupg/dev/api-service
   Key Files:
    key-pair/private-key.asc
    key-pair/public-key.asc
    pubring.kbx
    trustdb.gpg
----------------------------------------------------

Enter the number of the GPG keypair directory you want to back up:
1

Checking container access...
Container 'key-pairs-backup' exists.
Uploading GPG keypair directory files to Azure Blob Storage...
  Uploading /home/user/.gnupg/prod/myapp/key-pair/private-key.asc to prod/myapp/key-pair/private-key.asc ...
  Uploading /home/user/.gnupg/prod/myapp/key-pair/public-key.asc to prod/myapp/key-pair/public-key.asc ...
  Uploading /home/user/.gnupg/prod/myapp/pubring.kbx to prod/myapp/pubring.kbx ...
  Uploading /home/user/.gnupg/prod/myapp/trustdb.gpg to prod/myapp/trustdb.gpg ...

GPG keypair directory successfully backed up to Azure Blob Storage under:
  https://mystorageaccount.blob.core.windows.net/key-pairs-backup/prod/myapp/
```

### Azure Blob Structure

```
<container>/
├── prod/
│   └── myapp/
│       ├── key-pair/
│       │   ├── private-key.asc
│       │   └── public-key.asc
│       ├── pubring.kbx
│       └── trustdb.gpg
└── dev/
    └── api-service/
        ├── key-pair/
        │   ├── private-key.asc
        │   └── public-key.asc
        ├── pubring.kbx
        └── trustdb.gpg
```

### Features

✅ **Automatic container creation** - Creates if doesn't exist  
✅ **Structured paths** - `<env>/<project>/<filename>`  
✅ **Overwrite enabled** - Always uses latest version  
✅ **All files uploaded** - Entire directory structure  
✅ **Error handling** - Validates credentials and permissions  

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Azure CLI not installed |
| 1 | GPG directory doesn't exist |
| 1 | Missing credentials (STORAGE_ACCOUNT, STORAGE_KEY, or CONTAINER) |
| 1 | No keypair directories found |
| 1 | Invalid selection |
| 1 | Container creation failed |
| 1 | File upload failed |

### Error Handling

**Azure CLI not installed:**
```bash
Error: 'az' CLI is required. Please install Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli
```

**Missing credentials:**
```bash
Error: Missing STORAGE_ACCOUNT, STORAGE_KEY or CONTAINER. Check ./backup.conf or set defaults in the script.
```

**Container creation failure:**
```bash
Error: Failed to create container 'key-pairs-backup'.
```

**Upload failure:**
```bash
Error: Failed to upload /home/user/.gnupg/prod/myapp/private-key.asc.
```

### Verify Backup

**List uploaded blobs:**
```bash
az storage blob list \
  --account-name mystorageaccount \
  --account-key "$STORAGE_KEY" \
  --container-name key-pairs-backup \
  --prefix prod/myapp/ \
  --output table
```

**Download and verify:**
```bash
az storage blob download \
  --account-name mystorageaccount \
  --container-name key-pairs-backup \
  --name prod/myapp/key-pair/private-key.asc \
  --file /tmp/verify.asc

# Compare checksums
sha256sum ~/.gnupg/prod/myapp/key-pair/private-key.asc
sha256sum /tmp/verify.asc

# Clean up
shred -u /tmp/verify.asc
```

### Restore from Backup

**Manual restore:**
```bash
# Download specific file
az storage blob download \
  --account-name mystorageaccount \
  --container-name key-pairs-backup \
  --name prod/myapp/key-pair/private-key.asc \
  --file ~/.gnupg/prod/myapp/key-pair/private-key.asc

# Import key
gpg --import ~/.gnupg/prod/myapp/key-pair/private-key.asc
```

**Bulk restore:**
```bash
# Download entire directory
az storage blob download-batch \
  --account-name mystorageaccount \
  --source key-pairs-backup \
  --pattern "prod/myapp/*" \
  --destination ~/.gnupg/prod/myapp/
```

### Automation

**Backup all keypairs:**
```bash
#!/bin/bash
# backup-all.sh

for idx in $(seq 1 10); do
  echo "$idx" | ./backup_gpg_keypairs_to_azure.sh 2>/dev/null || true
done
```

**Scheduled backup (cron):**
```bash
# Edit crontab
crontab -e

# Add weekly backup (every Sunday at 2 AM)
0 2 * * 0 /path/to/backup_gpg_keypairs_to_azure.sh <<< "1" >> /var/log/gpg-backup.log 2>&1
```

### Security Considerations

1. **Credentials in backup.conf** - Keep file secure (chmod 600)
2. **Private keys uploaded** - Ensure Azure encryption at rest enabled
3. **Network transmission** - Azure CLI uses HTTPS by default
4. **Access logs** - Enable Azure Storage logging
5. **Lifecycle policies** - Configure retention and deletion

### Best Practices

1. **Regular backups** - Weekly for production keys
2. **Verify backups** - Periodically test restore process
3. **Document backups** - Maintain inventory of what's backed up
4. **Monitor costs** - Review Azure storage costs monthly
5. **Test restores** - Ensure backup can actually be restored

---

## Common Patterns

### Complete Project Setup

```bash
# 1. Generate keys for all environments
./generate_gpg_keypairs.sh myapp dev dev@company.com "DevPass!"
./generate_gpg_keypairs.sh myapp staging staging@company.com "StagingPass!"
./generate_gpg_keypairs.sh myapp prod prod@company.com "ProdPass!"

# 2. List all keys
./list_gpg_keypairs.sh

# 3. Encrypt configuration files
./generate_and_encrypt_file_gpg.sh myapp prod prod@company.com "ProdPass!" ./config.json

# 4. Backup production keys
./backup_gpg_keypairs_to_azure.sh
# Select production keypair

# 5. Verify backup
az storage blob list \
  --account-name mystorageaccount \
  --container-name key-pairs-backup \
  --prefix prod/myapp/
```

### Key Rotation

```bash
# 1. Backup existing keys
./backup_gpg_keypairs_to_azure.sh

# 2. Generate new keys (different email or manually delete first)
./manage_gpg_keypairs.sh  # Delete old keys
./generate_gpg_keypairs.sh myapp prod new@company.com "NewPass!"

# 3. Re-encrypt data with new keys
# [Manual process - decrypt with old key, re-encrypt with new]

# 4. Backup new keys
./backup_gpg_keypairs_to_azure.sh
```

---

**Last Updated**: December 8, 2025  
**Maintained By**: [Your Name/Team]
