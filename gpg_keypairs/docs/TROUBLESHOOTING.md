# Troubleshooting Guide

This guide provides solutions to common issues encountered when using the GPG keypair management utilities.

## Table of Contents

- [GPG-Related Issues](#gpg-related-issues)
- [Azure CLI Issues](#azure-cli-issues)
- [Script Execution Issues](#script-execution-issues)
- [Permission Issues](#permission-issues)
- [Encryption/Decryption Issues](#encryptiondecryption-issues)
- [Backup and Recovery Issues](#backup-and-recovery-issues)
- [Performance Issues](#performance-issues)
- [Diagnostic Tools](#diagnostic-tools)

---

## GPG-Related Issues

### Issue: "gpg: agent_genkey failed: No such file or directory"

**Symptoms:**
```
Error: GPG key generation failed
gpg: agent_genkey failed: No such file or directory
```

**Cause:** GPG agent is not running or has crashed.

**Solution:**
```bash
# Kill and restart GPG agent
gpgconf --kill gpg-agent
gpgconf --launch gpg-agent

# Verify agent is running
gpgconf --list-components | grep gpg-agent

# Try key generation again
./generate_gpg_keypairs.sh myapp prod user@example.com "password"
```

---

### Issue: "gpg: can't connect to the agent: IPC connect call failed"

**Symptoms:**
```
gpg: can't connect to the agent: IPC connect call failed
gpg: problem with the agent: No agent running
```

**Cause:** GPG agent socket is stale or permissions are incorrect.

**Solution:**
```bash
# Check GPG agent status
gpgconf --check-programs

# Remove stale socket
rm -f ~/.gnupg/S.gpg-agent
rm -f ~/.gnupg/S.gpg-agent.*

# Restart agent
gpgconf --kill gpg-agent
gpg-agent --daemon --use-standard-socket

# Verify
echo "test" | gpg --clearsign
```

---

### Issue: "gpg: keyserver receive failed: No keyserver available"

**Symptoms:**
```
gpg: keyserver receive failed: No keyserver available
```

**Cause:** No keyserver configured or network connectivity issues.

**Solution:**
```bash
# Add keyserver to GPG configuration
echo "keyserver hkps://keys.openpgp.org" >> ~/.gnupg/gpg.conf

# Or use specific keyserver
echo "keyserver hkps://keyserver.ubuntu.com" >> ~/.gnupg/gpg.conf

# Test keyserver connectivity
gpg --keyserver hkps://keys.openpgp.org --search-keys test@example.com
```

---

### Issue: "gpg: decryption failed: No secret key"

**Symptoms:**
```
gpg: encrypted with 4096-bit RSA key, ID XXXXX, created 2025-12-08
gpg: decryption failed: No secret key
```

**Cause:** Private key is not available in the specified GPG homedir.

**Solution:**
```bash
# List secret keys in the homedir
gpg --homedir ~/.gnupg/prod/myapp --list-secret-keys

# If key is missing, import it
gpg --homedir ~/.gnupg/prod/myapp --import private-key.asc

# Verify key is now available
gpg --homedir ~/.gnupg/prod/myapp --list-secret-keys

# Try decryption again
gpg --homedir ~/.gnupg/prod/myapp --decrypt file.gpg
```

---

### Issue: "gpg: public key decryption failed: Bad passphrase"

**Symptoms:**
```
gpg: public key decryption failed: Bad passphrase
gpg: decryption failed: No secret key
```

**Cause:** Incorrect passphrase provided.

**Solution:**
```bash
# Verify correct passphrase
# Try manual decryption to confirm
gpg --homedir ~/.gnupg/prod/myapp --decrypt file.gpg
# Enter passphrase when prompted

# If passphrase is forgotten, key cannot be recovered
# You must generate a new keypair

# Check if passphrase is in password manager
# Verify no extra spaces or special characters
```

---

### Issue: Duplicate key warning

**Symptoms:**
```
Warning: A key for 'user@example.com' already exists in ~/.gnupg/prod/myapp. 
Skipping key generation and reusing existing key.
```

**Cause:** Key already exists for the specified email address.

**Solution:**

**Option 1: Reuse existing key (default behavior)**
```bash
# Script will use existing key - no action needed
# This is the normal behavior
```

**Option 2: Delete and regenerate**
```bash
# Delete existing keypair
./manage_gpg_keypairs.sh
# Select the keypair number to delete
# Confirm deletion

# Generate new keypair
./generate_gpg_keypairs.sh myapp prod user@example.com "newpassword"
```

**Option 3: Use different email**
```bash
# Generate key with different email address
./generate_gpg_keypairs.sh myapp prod user2@example.com "password"
```

---

## Azure CLI Issues

### Issue: "az: command not found"

**Symptoms:**
```
Error: 'az' CLI is required. Please install Azure CLI
```

**Cause:** Azure CLI is not installed.

**Solution:**

**Ubuntu/Debian:**
```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
az --version
```

**macOS:**
```bash
brew install azure-cli
az --version
```

**Windows (PowerShell):**
```powershell
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
az --version
```

---

### Issue: "ERROR: Please run 'az login' to setup account"

**Symptoms:**
```
ERROR: Please run 'az login' to setup account.
```

**Cause:** Not authenticated to Azure.

**Solution:**
```bash
# Interactive login
az login

# Verify login
az account show

# List available subscriptions
az account list --output table

# Set specific subscription
az account set --subscription "subscription-name"
```

---

### Issue: Azure upload fails with "AuthorizationPermissionMismatch"

**Symptoms:**
```
ERROR: This request is not authorized to perform this operation using this permission.
Status: 403 (Forbidden)
```

**Cause:** Insufficient permissions on storage account or incorrect credentials.

**Solution:**

**Check credentials:**
```bash
# Verify storage account exists
az storage account show --name mystorageaccount

# Test connection
az storage container list \
  --account-name mystorageaccount \
  --account-key "$STORAGE_KEY"

# Regenerate storage key if needed
az storage account keys list \
  --account-name mystorageaccount \
  --resource-group myresourcegroup
```

**Check permissions:**
```bash
# List role assignments
az role assignment list \
  --assignee $(az account show --query user.name -o tsv) \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<account>

# Add required role
az role assignment create \
  --assignee user@example.com \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<account>
```

---

### Issue: "The specified container does not exist"

**Symptoms:**
```
The specified container does not exist.
ErrorCode: ContainerNotFound
```

**Cause:** Container doesn't exist and script failed to create it.

**Solution:**
```bash
# Manually create container
az storage container create \
  --account-name mystorageaccount \
  --account-key "$STORAGE_KEY" \
  --name key-pairs-backup

# Verify creation
az storage container list \
  --account-name mystorageaccount \
  --account-key "$STORAGE_KEY" \
  --output table

# Re-run backup script
./backup_gpg_keypairs_to_azure.sh
```

---

## Script Execution Issues

### Issue: "Permission denied" when running script

**Symptoms:**
```bash
$ ./generate_gpg_keypairs.sh
bash: ./generate_gpg_keypairs.sh: Permission denied
```

**Cause:** Script doesn't have execute permissions.

**Solution:**
```bash
# Add execute permission
chmod +x generate_gpg_keypairs.sh

# Or for all scripts
chmod +x *.sh

# Verify permissions
ls -la *.sh

# Run script
./generate_gpg_keypairs.sh
```

---

### Issue: "bad interpreter: /bin/bash: no such file or directory"

**Symptoms:**
```
bash: ./generate_gpg_keypairs.sh: /bin/bash: bad interpreter: No such file or directory
```

**Cause:** Bash is not located at `/bin/bash` (common on some systems) or Windows line endings.

**Solution:**

**Option 1: Update shebang**
```bash
# Find bash location
which bash

# Update first line of script
# Change: #!/bin/bash
# To: #!/usr/bin/env bash
```

**Option 2: Fix line endings (if from Windows)**
```bash
# Install dos2unix
sudo apt-get install dos2unix  # Ubuntu/Debian
brew install dos2unix          # macOS

# Convert line endings
dos2unix *.sh

# Verify
file generate_gpg_keypairs.sh
# Should show: ASCII text, with LF line terminators
```

---

### Issue: "Invalid email address"

**Symptoms:**
```
Error: Invalid email address: userexample.com
```

**Cause:** Email format doesn't match validation regex.

**Solution:**
```bash
# Ensure email format: user@domain.tld
# Valid examples:
./generate_gpg_keypairs.sh myapp prod user@example.com "pass"
./generate_gpg_keypairs.sh myapp prod user.name@company.co.uk "pass"

# Invalid examples:
./generate_gpg_keypairs.sh myapp prod userexample.com "pass"      # Missing @
./generate_gpg_keypairs.sh myapp prod user@example "pass"         # Missing TLD
./generate_gpg_keypairs.sh myapp prod @example.com "pass"         # Missing username
```

---

### Issue: "Output file already exists"

**Symptoms:**
```
Error: Output file already exists: data.csv.gpg. Provide OVERWRITE=1 to overwrite.
```

**Cause:** Encrypted file already exists and overwrite flag not provided.

**Solution:**

**Option 1: Allow overwrite**
```bash
./generate_and_encrypt_file_gpg.sh myapp prod user@example.com "pass" data.csv 1
```

**Option 2: Backup existing file**
```bash
mv data.csv.gpg data.csv.gpg.backup
./generate_and_encrypt_file_gpg.sh myapp prod user@example.com "pass" data.csv
```

**Option 3: Delete existing file**
```bash
rm data.csv.gpg
./generate_and_encrypt_file_gpg.sh myapp prod user@example.com "pass" data.csv
```

---

## Permission Issues

### Issue: "Failed to create directory: Permission denied"

**Symptoms:**
```
Error: Failed to create directory: /home/user/.gnupg/prod/myapp
mkdir: cannot create directory '/home/user/.gnupg/prod/myapp': Permission denied
```

**Cause:** No write permissions to parent directory.

**Solution:**
```bash
# Check current permissions
ls -la ~/.gnupg

# Fix ownership
sudo chown -R $USER:$USER ~/.gnupg

# Fix permissions
chmod 700 ~/.gnupg

# Try again
./generate_gpg_keypairs.sh myapp prod user@example.com "pass"
```

---

### Issue: GPG warns about unsafe permissions

**Symptoms:**
```
gpg: WARNING: unsafe permissions on homedir '/home/user/.gnupg'
```

**Cause:** GPG directory has overly permissive permissions.

**Solution:**
```bash
# Fix GPG directory permissions recursively
chmod 700 ~/.gnupg
find ~/.gnupg -type d -exec chmod 700 {} \;
find ~/.gnupg -type f -exec chmod 600 {} \;

# Public keys can be more permissive
find ~/.gnupg -name "public-key.asc" -exec chmod 644 {} \;

# Verify
ls -la ~/.gnupg
```

---

## Encryption/Decryption Issues

### Issue: "File encryption failed"

**Symptoms:**
```
Error: File encryption failed
gpg: <email>: skipped: No public key
gpg: [stdin]: encryption failed: No public key
```

**Cause:** Public key not found for recipient email.

**Solution:**
```bash
# List available public keys
gpg --homedir ~/.gnupg/prod/myapp --list-keys

# If key is missing, import it
gpg --homedir ~/.gnupg/prod/myapp --import public-key.asc

# Verify recipient email matches key
gpg --homedir ~/.gnupg/prod/myapp --list-keys user@example.com

# Try encryption again
gpg --batch --yes \
  --homedir ~/.gnupg/prod/myapp \
  --encrypt -r user@example.com \
  -o output.gpg \
  input.txt
```

---

### Issue: Decryption hangs waiting for passphrase

**Symptoms:**
- Script hangs indefinitely
- No error message displayed

**Cause:** GPG is waiting for passphrase input via pinentry GUI.

**Solution:**
```bash
# Use --pinentry-mode loopback for non-interactive decryption
gpg --batch \
  --homedir ~/.gnupg/prod/myapp \
  --pinentry-mode loopback \
  --passphrase "yourpassword" \
  --decrypt file.gpg

# Or configure in gpg.conf
echo "pinentry-mode loopback" >> ~/.gnupg/prod/myapp/gpg.conf

# For GPG 2.1+, also add to gpg-agent.conf
echo "allow-loopback-pinentry" >> ~/.gnupg/gpg-agent.conf
gpgconf --kill gpg-agent
```

---

## Backup and Recovery Issues

### Issue: Backup script shows no keypairs found

**Symptoms:**
```
No GPG keypair directories found in /home/user/.gnupg.
```

**Cause:** No keypairs exist or they're in non-standard location.

**Solution:**
```bash
# Verify GPG directory structure
ls -la ~/.gnupg/

# Expected structure:
# ~/.gnupg/<env>/<project>/

# Generate a keypair if none exist
./generate_gpg_keypairs.sh myapp dev user@example.com "pass"

# List keypairs
./list_gpg_keypairs.sh

# Run backup again
./backup_gpg_keypairs_to_azure.sh
```

---

### Issue: "Failed to upload file to Azure"

**Symptoms:**
```
Error: Failed to upload /home/user/.gnupg/prod/myapp/private-key.asc.
```

**Cause:** Network connectivity, permissions, or storage quota issues.

**Solution:**

**Check connectivity:**
```bash
# Test Azure connectivity
az storage account show --name mystorageaccount

# Check network
ping mystorageaccount.blob.core.windows.net
```

**Check storage quota:**
```bash
# Check storage usage
az storage account show-usage --name mystorageaccount

# Check container quota
az storage container show \
  --account-name mystorageaccount \
  --name key-pairs-backup
```

**Manual upload test:**
```bash
# Create test file
echo "test" > /tmp/test.txt

# Try manual upload
az storage blob upload \
  --account-name mystorageaccount \
  --account-key "$STORAGE_KEY" \
  --container-name key-pairs-backup \
  --name test.txt \
  --file /tmp/test.txt \
  --verbose
```

---

### Issue: Cannot restore backup from Azure

**Symptoms:**
- Downloaded file is corrupt
- GPG cannot import restored key

**Solution:**
```bash
# Download with verification
az storage blob download \
  --account-name mystorageaccount \
  --container-name key-pairs-backup \
  --name prod/myapp/key-pair/private-key.asc \
  --file /tmp/restored-key.asc \
  --validate-content

# Verify file integrity
file /tmp/restored-key.asc
# Should show: "PGP private key block"

# Check file size matches
az storage blob show \
  --account-name mystorageaccount \
  --container-name key-pairs-backup \
  --name prod/myapp/key-pair/private-key.asc \
  --query properties.contentLength

ls -l /tmp/restored-key.asc

# Import key
gpg --import /tmp/restored-key.asc

# Securely delete temporary file
shred -u /tmp/restored-key.asc
```

---

## Performance Issues

### Issue: Script runs very slowly

**Symptoms:**
- Key generation takes several minutes
- Backup upload is extremely slow

**Causes & Solutions:**

**Slow key generation:**
```bash
# Increase system entropy
# Install rng-tools (Ubuntu/Debian)
sudo apt-get install rng-tools
sudo systemctl start rng-tools

# Check entropy available
cat /proc/sys/kernel/random/entropy_avail
# Should be > 1000

# Generate some entropy
ls -R / > /dev/null 2>&1 &
```

**Slow Azure upload:**
```bash
# Check network bandwidth
curl -o /dev/null http://speedtest.ftp.otenet.gr/files/test100Mb.db

# Use Azure region closer to your location
# Update storage account or create new one

# Check for network throttling
az storage account show \
  --name mystorageaccount \
  --query networkRuleSet

# Consider using AzCopy for bulk uploads
azcopy copy \
  "/home/user/.gnupg/prod/myapp/*" \
  "https://mystorageaccount.blob.core.windows.net/key-pairs-backup/prod/myapp/" \
  --recursive
```

---

## Diagnostic Tools

### Enable Debug Mode

```bash
# Add to top of script after shebang
set -x  # Print commands and arguments as executed
set -v  # Print shell input lines as read

# Or run script with debug
bash -x ./generate_gpg_keypairs.sh myapp prod user@example.com "pass"
```

### GPG Diagnostics

```bash
# Check GPG version
gpg --version

# List all GPG components
gpgconf --list-components

# Check GPG configuration
gpg --version --verbose

# List all keys with details
gpg --list-keys --verbose
gpg --list-secret-keys --verbose

# Check agent status
gpgconf --check-programs

# View GPG agent logs
cat ~/.gnupg/gpg-agent.log
```

### Azure Diagnostics

```bash
# Azure CLI version
az --version

# Current subscription
az account show

# Test storage connection
az storage account show --name mystorageaccount

# Enable debug output
az storage blob upload --name test.txt --file test.txt --debug

# Check Azure activity log
az monitor activity-log list \
  --resource-group myresourcegroup \
  --start-time 2025-12-08T00:00:00Z
```

### System Diagnostics

```bash
# Check disk space
df -h ~/.gnupg

# Check file descriptors
lsof | grep gpg

# Check running processes
ps aux | grep gpg

# Check system resources
top
htop

# Check network connectivity
netstat -tuln | grep gpg
ss -tuln | grep gpg
```

### Collect Diagnostic Information

```bash
#!/bin/bash
# collect-diagnostics.sh

echo "=== System Information ==="
uname -a
lsb_release -a 2>/dev/null || cat /etc/os-release

echo -e "\n=== GPG Version ==="
gpg --version

echo -e "\n=== GPG Components ==="
gpgconf --list-components

echo -e "\n=== GPG Directory Permissions ==="
ls -la ~/.gnupg

echo -e "\n=== Azure CLI Version ==="
az --version

echo -e "\n=== Azure Account ==="
az account show

echo -e "\n=== Disk Space ==="
df -h ~/.gnupg

echo -e "\n=== Entropy Available ==="
cat /proc/sys/kernel/random/entropy_avail

echo -e "\n=== Recent GPG Errors ==="
tail -20 ~/.gnupg/gpg-agent.log 2>/dev/null || echo "No log file found"
```

Run diagnostics:
```bash
chmod +x collect-diagnostics.sh
./collect-diagnostics.sh > diagnostics.txt 2>&1
```

---

## Getting Help

If you've tried the solutions above and still encounter issues:

1. **Check the documentation**
   - Review [README.md](./README.md)
   - Review [SECURITY.md](./SECURITY.md)

2. **Collect diagnostic information**
   ```bash
   ./collect-diagnostics.sh > diagnostics.txt
   ```

3. **Search for similar issues**
   - GPG Issues: https://dev.gnupg.org/
   - Azure CLI Issues: https://github.com/Azure/azure-cli/issues

4. **Open an issue**
   - Include diagnostic information
   - Describe what you tried
   - Include error messages (redact sensitive info)

5. **Community resources**
   - Stack Overflow: [gpg] [azure-cli] tags
   - Unix StackExchange for Linux-specific issues

---

## Common Error Codes

| Error Code | Description | Common Cause |
|------------|-------------|--------------|
| 2 | General error | Various - check error message |
| 11 | Bad passphrase | Incorrect passphrase |
| 13 | Permission denied | File/directory permissions |
| 17 | File exists | Output file already exists |
| 33 | No public key | Public key not in keyring |
| 53 | Bad key | Corrupted or invalid key |
| 58 | No data | Empty or corrupted file |
| 127 | Command not found | Missing GPG or Azure CLI |

---

**Last Updated**: December 8, 2025  
**Maintained By**: [Your Name/Team]
