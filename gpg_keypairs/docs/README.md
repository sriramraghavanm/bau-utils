# GPG Keypair Management Utilities

A comprehensive suite of Bash scripts for managing GPG keypairs across multiple projects and environments, with Azure Blob Storage backup capabilities.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Generate GPG Keypairs](#generate-gpg-keypairs)
  - [Generate Keypairs and Encrypt Files](#generate-keypairs-and-encrypt-files)
  - [List GPG Keypairs](#list-gpg-keypairs)
  - [Manage Keypairs (Delete)](#manage-keypairs-delete)
  - [Backup to Azure](#backup-to-azure)
- [Directory Structure](#directory-structure)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## Overview

This toolkit provides automated management of GPG keypairs organized by environment (dev, staging, prod) and project name. It supports:

- **Isolated keypair generation** per project and environment
- **File encryption** using generated keypairs
- **Keypair listing and inspection**
- **Safe deletion** with confirmation prompts
- **Azure Blob Storage backup** for disaster recovery

## Features

✅ **Multi-Environment Support**: Organize keys by environment (dev/staging/prod) and project  
✅ **Non-Interactive Key Generation**: Batch mode with no GUI prompts  
✅ **Strong Encryption**: RSA-4096 keys (configurable)  
✅ **Cloud Backup**: Automated Azure Blob Storage backup  
✅ **Safe Operations**: Overwrite protection and confirmation prompts  
✅ **Portable Keys**: ASCII-armored export format  
✅ **Error Handling**: Comprehensive validation and error reporting  

## Prerequisites

### Required Software

- **Bash** 4.0 or higher
- **GnuPG** 2.2 or higher
  ```bash
  # Ubuntu/Debian
  sudo apt-get install gnupg
  
  # macOS
  brew install gnupg
  
  # Verify installation
  gpg --version
  ```

- **Azure CLI** (for backup functionality only)
  ```bash
  # Install Azure CLI
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
  
  # Login to Azure
  az login
  
  # Verify installation
  az --version
  ```

### Required Permissions

- Read/write access to `~/.gnupg` directory
- Azure Storage Account access (for backup operations)

## Installation

1. **Clone or download the scripts** to your desired directory:
   ```bash
   cd ~/tools
   git clone <repository-url> gpg_keypairs
   cd gpg_keypairs
   ```

2. **Make scripts executable**:
   ```bash
   chmod +x *.sh
   ```

3. **Verify installation**:
   ```bash
   ./list_gpg_keypairs.sh
   ```

## Configuration

### Azure Backup Configuration

Create or edit `backup.conf` in the same directory as the scripts:

```bash
# Azure Storage Account Configuration
STORAGE_ACCOUNT="your-storage-account-name"
STORAGE_KEY="your-storage-account-key"
CONTAINER="key-pairs-backup"
```

**Security Note**: Keep `backup.conf` secure and never commit it to version control.

```bash
# Add to .gitignore
echo "backup.conf" >> .gitignore
```

### Environment Variables (Optional)

You can also set these as environment variables:

```bash
export STORAGE_ACCOUNT="your-storage-account-name"
export STORAGE_KEY="your-storage-account-key"
export CONTAINER="key-pairs-backup"
```

## Usage

### Generate GPG Keypairs

**Script**: `generate_gpg_keypairs.sh`

Generates a GPG keypair for a specific project and environment.

#### Syntax
```bash
./generate_gpg_keypairs.sh <project_name> <env> <email> <passkey>
```

#### Parameters
- `project_name`: Name of the project (e.g., "myapp", "api-service")
- `env`: Environment name (e.g., "dev", "staging", "prod")
- `email`: Email address associated with the key
- `passkey`: Passphrase to protect the private key

#### Examples
```bash
# Generate keypair for production environment
./generate_gpg_keypairs.sh myapp prod admin@example.com "SecurePass123!"

# Generate keypair for development
./generate_gpg_keypairs.sh api-service dev dev@example.com "DevPass456!"
```

#### Output
Keys are generated in: `~/.gnupg/<env>/<project_name>/key-pair/`
- `public-key.asc`: ASCII-armored public key
- `private-key.asc`: ASCII-armored private key (keep secure!)

#### Key Specifications
- **Key Type**: RSA
- **Key Length**: 2048 bits
- **Subkey Type**: RSA
- **Subkey Length**: 2048 bits
- **Expiration**: 3 years

---

### Generate Keypairs and Encrypt Files

**Script**: `generate_and_encrypt_file_gpg.sh`

Generates GPG keypairs (or reuses existing) and encrypts a specified file.

#### Syntax
```bash
./generate_and_encrypt_file_gpg.sh <project_name> <env> <email> <passkey> <input_file> [OVERWRITE]
```

#### Parameters
- `project_name`: Name of the project
- `env`: Environment name
- `email`: Email address for the key
- `passkey`: Passphrase for the private key
- `input_file`: File to encrypt
- `OVERWRITE`: Optional flag (1) to overwrite existing `.gpg` file

#### Examples
```bash
# Encrypt a CSV file
./generate_and_encrypt_file_gpg.sh myapp prod admin@example.com "Pass123!" ./data.csv

# Encrypt with overwrite permission
./generate_and_encrypt_file_gpg.sh myapp prod admin@example.com "Pass123!" ./data.csv 1
```

#### Output
- Encrypted file: `<input_file>.gpg`
- Example: `data.csv` → `data.csv.gpg`

#### Key Specifications
- **Key Type**: RSA
- **Key Length**: 4096 bits (stronger than basic generation)
- **Subkey Type**: RSA
- **Subkey Length**: 4096 bits
- **Expiration**: 3 years

#### Features
- ✅ Email validation
- ✅ Input file existence check
- ✅ Overwrite protection
- ✅ Reuses existing keys if present
- ✅ Stronger RSA-4096 encryption

---

### List GPG Keypairs

**Script**: `list_gpg_keypairs.sh`

Scans and displays all GPG keypairs organized by environment and project.

#### Syntax
```bash
./list_gpg_keypairs.sh [base_gpg_dir]
```

#### Parameters
- `base_gpg_dir`: Optional custom GPG directory (default: `~/.gnupg`)

#### Examples
```bash
# List all keypairs in default directory
./list_gpg_keypairs.sh

# List keypairs in custom directory
./list_gpg_keypairs.sh /path/to/custom/gnupg
```

#### Sample Output
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

---

### Manage Keypairs (Delete)

**Script**: `manage_gpg_keypairs.sh`

Interactive script to list and delete GPG keypairs.

#### Syntax
```bash
./manage_gpg_keypairs.sh [base_gpg_dir]
```

#### Parameters
- `base_gpg_dir`: Optional custom GPG directory (default: `~/.gnupg`)

#### Examples
```bash
# Manage keypairs interactively
./manage_gpg_keypairs.sh

# Manage keypairs in custom directory
./manage_gpg_keypairs.sh /path/to/custom/gnupg
```

#### Workflow
1. Displays numbered list of all keypairs
2. Prompts for keypair numbers to delete (space-separated)
3. Requests confirmation (`yes`) for each deletion
4. Removes keys and homedir
5. Displays updated list

#### Sample Session
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

Enter the numbers of the key pairs you want to delete, separated by spaces:
1

Are you sure you want to delete all keys in '/home/user/.gnupg/prod/myapp'? 
This CANNOT be undone. Type 'yes' to confirm: yes
Deleted GPG key pair and homedir: /home/user/.gnupg/prod/myapp
```

---

### Backup to Azure

**Script**: `backup_gpg_keypairs_to_azure.sh`

Backs up selected GPG keypair directory to Azure Blob Storage.

#### Syntax
```bash
./backup_gpg_keypairs_to_azure.sh
```

#### Prerequisites
1. Azure CLI installed and authenticated
2. `backup.conf` configured with storage credentials
3. Appropriate Azure permissions

#### Configuration Required
Create `backup.conf`:
```bash
STORAGE_ACCOUNT="mystorageaccount"
STORAGE_KEY="base64-encoded-key"
CONTAINER="key-pairs-backup"
```

#### Workflow
1. Lists all available keypair directories
2. Prompts for selection by number
3. Verifies/creates Azure container
4. Uploads all files from selected directory
5. Displays blob storage URL

#### Sample Session
```
Scanning for GPG keypair directories in: /home/user/.gnupg

1) Environment: prod
   Project: myapp
   GPG Key Directory: /home/user/.gnupg/prod/myapp
   Key Files:
    private-key.asc
    public-key.asc
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

GPG keypair directory successfully backed up to Azure Blob Storage under:
  https://mystorageaccount.blob.core.windows.net/key-pairs-backup/prod/myapp/
```

#### Azure Blob Structure
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
        └── ...
```

---

## Directory Structure

```
~/.gnupg/
├── <env>/                          # Environment (dev, staging, prod)
│   └── <project_name>/             # Project name
│       ├── key-pair/               # Exported keypairs
│       │   ├── private-key.asc     # ASCII-armored private key
│       │   └── public-key.asc      # ASCII-armored public key
│       ├── pubring.kbx             # Public keyring database
│       ├── trustdb.gpg             # Trust database
│       └── private-keys-v1.d/      # Private key storage
```

### Script Directory
```
gpg_keypairs/
├── backup_gpg_keypairs_to_azure.sh
├── backup.conf                     # Azure configuration (git-ignored)
├── generate_and_encrypt_file_gpg.sh
├── generate_gpg_keypairs.sh
├── list_gpg_keypairs.sh
├── manage_gpg_keypairs.sh
├── README.md
├── SECURITY.md
└── TROUBLESHOOTING.md
```

---

## Security Considerations

### ⚠️ Critical Security Practices

1. **Private Keys**
   - Never commit private keys to version control
   - Store private keys in secure, encrypted storage
   - Use strong passphrases (minimum 16 characters)
   - Regularly rotate keypairs

2. **Passphrases**
   - Use password managers to generate/store passphrases
   - Never hardcode passphrases in scripts
   - Avoid reusing passphrases across environments

3. **Azure Credentials**
   - Keep `backup.conf` out of version control
   - Use Azure Key Vault for production credentials
   - Rotate storage account keys regularly
   - Use SAS tokens instead of storage account keys when possible

4. **File Permissions**
   - GPG directories are automatically set to `700` (owner-only access)
   - Verify permissions: `ls -la ~/.gnupg`
   - Never make GPG directories world-readable

5. **Backup Security**
   - Enable encryption at rest for Azure Storage
   - Use private endpoints for storage accounts
   - Enable soft delete for blob recovery
   - Implement lifecycle policies for retention

### Recommended `.gitignore`
```gitignore
# GPG sensitive files
backup.conf
*.asc
*.gpg
*.key
private-key*

# Environment files
.env
.env.local
```

---

## Troubleshooting

### Common Issues

#### 1. "gpg: agent_genkey failed: No such file or directory"
**Cause**: GPG agent not running  
**Solution**:
```bash
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent
```

#### 2. "Permission denied" errors
**Cause**: Incorrect directory permissions  
**Solution**:
```bash
chmod 700 ~/.gnupg
chmod 700 ~/.gnupg/<env>/<project>
```

#### 3. Azure upload fails with authentication error
**Cause**: Not logged into Azure CLI  
**Solution**:
```bash
az login
az account show  # Verify current subscription
```

#### 4. "Invalid email address" error
**Cause**: Email format validation failed  
**Solution**: Ensure email matches pattern `user@domain.tld`

#### 5. Duplicate keys warning
**Cause**: Key already exists for the email  
**Solution**: The script will reuse existing keys. To regenerate, delete first using `manage_gpg_keypairs.sh`

### Debug Mode

Enable verbose output for troubleshooting:
```bash
# Add to top of any script
set -x  # Enable debug tracing
```

### Log Files

GPG operations log to:
```bash
# View GPG logs
cat ~/.gnupg/gpg-agent.log
```

For more detailed troubleshooting, see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)

---

## Best Practices

1. **Environment Naming**: Use consistent names (dev/staging/prod)
2. **Project Naming**: Use kebab-case (e.g., `my-api-service`)
3. **Regular Backups**: Schedule weekly backups to Azure
4. **Key Rotation**: Rotate production keys annually
5. **Documentation**: Document which keys are used for what purpose
6. **Testing**: Test encryption/decryption after key generation
7. **Monitoring**: Monitor Azure storage costs and usage

---

## Examples & Workflows

### Complete Workflow: New Project Setup

```bash
# 1. Generate production keypair
./generate_gpg_keypairs.sh payment-api prod security@company.com "SecurePass123!"

# 2. Generate development keypair
./generate_gpg_keypairs.sh payment-api dev dev@company.com "DevPass456!"

# 3. Verify keys created
./list_gpg_keypairs.sh

# 4. Encrypt sensitive configuration
./generate_and_encrypt_file_gpg.sh payment-api prod security@company.com "SecurePass123!" ./prod-config.json

# 5. Backup production keys to Azure
./backup_gpg_keypairs_to_azure.sh
# Select the production keypair when prompted

# 6. Verify backup
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --account-key $STORAGE_KEY \
  --container-name $CONTAINER \
  --prefix prod/payment-api/
```

### Workflow: Key Cleanup

```bash
# 1. List all keys
./list_gpg_keypairs.sh

# 2. Delete old/unused keys
./manage_gpg_keypairs.sh
# Select numbers of keys to delete

# 3. Verify deletion
./list_gpg_keypairs.sh
```

---

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Commit changes (`git commit -am 'Add new feature'`)
4. Push to branch (`git push origin feature/improvement`)
5. Create a Pull Request

### Code Standards
- Follow existing script structure
- Add error handling for new features
- Update documentation
- Test on multiple environments

---

## License

[Specify your license here - e.g., MIT, Apache 2.0]

---

## Support

For issues, questions, or contributions:
- **Issues**: [GitHub Issues](https://github.com/your-repo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-repo/discussions)
- **Email**: support@yourcompany.com

---

## Changelog

### Version 1.0.0 (Current)
- Initial release
- GPG keypair generation
- File encryption
- Azure backup functionality
- Interactive management interface

---

**Last Updated**: December 8, 2025  
**Maintained By**: [Your Name/Team]
