# Security Guide for GPG Keypair Management

This document outlines security best practices for managing GPG keypairs and Azure credentials when using this toolkit.

## Table of Contents

- [Overview](#overview)
- [GPG Security Best Practices](#gpg-security-best-practices)
- [Passphrase Management](#passphrase-management)
- [Azure Credentials Security](#azure-credentials-security)
- [File and Directory Permissions](#file-and-directory-permissions)
- [Backup Security](#backup-security)
- [Key Lifecycle Management](#key-lifecycle-management)
- [Incident Response](#incident-response)
- [Compliance Considerations](#compliance-considerations)

---

## Overview

Security is paramount when managing cryptographic keys. This guide provides comprehensive security recommendations for:

- ✅ Protecting private keys from unauthorized access
- ✅ Securing passphrases and credentials
- ✅ Implementing proper access controls
- ✅ Maintaining secure backups
- ✅ Responding to security incidents

---

## GPG Security Best Practices

### Private Key Protection

#### Critical Rules

1. **Never Commit Private Keys to Version Control**
   ```bash
   # Add to .gitignore
   echo "*.asc" >> .gitignore
   echo "private-key*" >> .gitignore
   echo "*-private.key" >> .gitignore
   echo "backup.conf" >> .gitignore
   ```

2. **Encrypt Private Keys at Rest**
   ```bash
   # All generated private keys are already passphrase-protected
   # Verify private key is encrypted
   gpg --homedir ~/.gnupg/prod/myapp --list-secret-keys
   ```

3. **Limit Private Key Copies**
   - Keep only necessary copies
   - Document all storage locations
   - Destroy old copies securely when rotating keys

4. **Use Strong Passphrases**
   - Minimum 16 characters
   - Mix of uppercase, lowercase, numbers, symbols
   - Use a passphrase generator
   - Never reuse passphrases

#### File Permissions

```bash
# Verify GPG directory permissions (should be 700)
ls -la ~/.gnupg

# Fix permissions if needed
chmod 700 ~/.gnupg
chmod 700 ~/.gnupg/<env>/<project>
chmod 600 ~/.gnupg/<env>/<project>/key-pair/private-key.asc

# Recursively fix all GPG directories
find ~/.gnupg -type d -exec chmod 700 {} \;
find ~/.gnupg -type f -exec chmod 600 {} \;
```

### Public Key Distribution

Public keys can be shared freely, but follow these practices:

1. **Verify Integrity**
   ```bash
   # Generate fingerprint for verification
   gpg --homedir ~/.gnupg/prod/myapp --fingerprint user@example.com
   ```

2. **Use Secure Channels**
   - Distribute via HTTPS
   - Include fingerprints separately
   - Verify fingerprints out-of-band

3. **Key Server Considerations**
   - Consider uploading to public keyservers for discoverability
   - Include revocation certificate capability
   - Document key server locations

---

## Passphrase Management

### Strong Passphrase Requirements

**Minimum Requirements:**
- Length: 16+ characters
- Complexity: Mixed case, numbers, symbols
- Entropy: 80+ bits
- No dictionary words or personal information

### Passphrase Generation

```bash
# Generate strong passphrase (Linux/macOS)
openssl rand -base64 32

# Generate pronounceable passphrase
pwgen -s 20 1

# Using password manager
# Recommended: Use tools like 1Password, Bitwarden, or KeePass
```

### Passphrase Storage

#### ❌ Never Store Passphrases In:
- Plain text files
- Shell history
- Environment variables (for long-term storage)
- Code repositories
- Email or chat messages

#### ✅ Recommended Storage:
- **Enterprise Password Manager** (1Password, LastPass, Bitwarden)
- **Hardware Security Module (HSM)**
- **Azure Key Vault** (for automated systems)
- **Encrypted password database** (KeePass with strong master password)

### Script Usage Security

```bash
# ❌ NEVER do this:
./generate_gpg_keypairs.sh myapp prod user@example.com "password123"
# ^ Passphrase visible in shell history and process list

# ✅ Better approach - prompt for passphrase:
read -s -p "Enter passphrase: " PASSKEY
echo
./generate_gpg_keypairs.sh myapp prod user@example.com "$PASSKEY"
unset PASSKEY

# ✅ Best approach - retrieve from password manager:
PASSKEY=$(security find-generic-password -w -s "gpg-myapp-prod" -a "$USER")
./generate_gpg_keypairs.sh myapp prod user@example.com "$PASSKEY"
unset PASSKEY
```

### Passphrase Rotation

- **Production keys**: Rotate annually
- **Development keys**: Rotate every 6 months
- **After personnel changes**: Rotate immediately
- **Suspected compromise**: Rotate immediately and revoke old keys

---

## Azure Credentials Security

### Storage Account Key Protection

#### Secure Configuration Management

```bash
# ❌ Never hardcode credentials
STORAGE_KEY="o9HwY63YcNGxH39eEpD..."  # BAD!

# ✅ Use configuration file with restricted permissions
cat > backup.conf << 'EOF'
STORAGE_ACCOUNT="mystorageaccount"
STORAGE_KEY="$(get-secret-from-vault)"
CONTAINER="key-pairs-backup"
EOF
chmod 600 backup.conf

# ✅ Better - use Azure Key Vault
STORAGE_KEY=$(az keyvault secret show \
  --vault-name mykeyvault \
  --name storage-account-key \
  --query value -o tsv)
```

#### Use SAS Tokens Instead of Account Keys

```bash
# Generate SAS token with limited permissions and time window
az storage container generate-sas \
  --account-name mystorageaccount \
  --name key-pairs-backup \
  --permissions racw \
  --expiry 2025-12-31T23:59:59Z \
  --https-only \
  --output tsv

# Store SAS token in Key Vault
az keyvault secret set \
  --vault-name mykeyvault \
  --name storage-sas-token \
  --value "<sas-token>"
```

#### Managed Identity (Recommended for Production)

```bash
# Enable managed identity on VM/Container
az vm identity assign --name myvm --resource-group myrg

# Grant access to storage account
az role assignment create \
  --assignee <managed-identity-id> \
  --role "Storage Blob Data Contributor" \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<account>

# No credentials needed - use managed identity
az storage blob upload \
  --account-name mystorageaccount \
  --auth-mode login \
  --container-name key-pairs-backup \
  --name myfile \
  --file ./myfile
```

### Azure Security Best Practices

1. **Enable Azure Storage Encryption at Rest**
   ```bash
   # Verify encryption enabled (should be by default)
   az storage account show \
     --name mystorageaccount \
     --query encryption
   ```

2. **Use Private Endpoints**
   ```bash
   # Create private endpoint for storage account
   az network private-endpoint create \
     --name storage-private-endpoint \
     --resource-group myrg \
     --vnet-name myvnet \
     --subnet mysubnet \
     --private-connection-resource-id <storage-account-id> \
     --group-id blob \
     --connection-name storage-connection
   ```

3. **Enable Soft Delete**
   ```bash
   # Enable blob soft delete (7-day retention)
   az storage blob service-properties delete-policy update \
     --account-name mystorageaccount \
     --enable true \
     --days-retained 7
   ```

4. **Restrict Network Access**
   ```bash
   # Allow access only from specific IP ranges
   az storage account update \
     --name mystorageaccount \
     --resource-group myrg \
     --default-action Deny
   
   az storage account network-rule add \
     --account-name mystorageaccount \
     --ip-address 203.0.113.10
   ```

5. **Enable Logging and Monitoring**
   ```bash
   # Enable diagnostic logging
   az monitor diagnostic-settings create \
     --name storage-diagnostics \
     --resource <storage-account-id> \
     --logs '[{"category": "StorageRead", "enabled": true}]' \
     --metrics '[{"category": "Transaction", "enabled": true}]' \
     --workspace <log-analytics-workspace-id>
   ```

---

## File and Directory Permissions

### Linux/macOS Permissions

```bash
# GPG home directory structure
~/.gnupg/                    # 700 (drwx------)
├── prod/                    # 700 (drwx------)
│   └── myapp/               # 700 (drwx------)
│       ├── key-pair/        # 700 (drwx------)
│       │   ├── private-key.asc  # 600 (-rw-------)
│       │   └── public-key.asc   # 644 (-rw-r--r--)
│       ├── pubring.kbx      # 600 (-rw-------)
│       └── trustdb.gpg      # 600 (-rw-------)
```

### Automated Permission Fix

```bash
#!/bin/bash
# fix-gpg-permissions.sh

GPG_BASE="${1:-$HOME/.gnupg}"

echo "Fixing permissions for: $GPG_BASE"

# Fix directory permissions
find "$GPG_BASE" -type d -exec chmod 700 {} \;

# Fix file permissions
find "$GPG_BASE" -type f -exec chmod 600 {} \;

# Public keys can be readable
find "$GPG_BASE" -name "public-key.asc" -exec chmod 644 {} \;
find "$GPG_BASE" -name "*.pub" -exec chmod 644 {} \;

echo "Permissions fixed successfully"
```

### Windows Permissions

```powershell
# Set ACL to owner-only access
$gpgPath = "$env:USERPROFILE\.gnupg"
$acl = Get-Acl $gpgPath

# Remove inherited permissions
$acl.SetAccessRuleProtection($true, $false)

# Add owner full control
$owner = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $owner, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.AddAccessRule($accessRule)

# Apply ACL
Set-Acl $gpgPath $acl
```

---

## Backup Security

### Encrypted Backups

#### Option 1: Azure Storage Encryption (Recommended)

```bash
# Verify encryption at rest is enabled
az storage account show \
  --name mystorageaccount \
  --query "encryption.services.blob.enabled"

# Enable customer-managed keys for additional control
az storage account encryption-scope create \
  --account-name mystorageaccount \
  --name backup-encryption \
  --key-source Microsoft.Keyvault \
  --key-uri "https://mykeyvault.vault.azure.net/keys/mykey"
```

#### Option 2: Client-Side Encryption

```bash
# Encrypt before uploading
tar czf - ~/.gnupg/prod/myapp | \
  gpg --symmetric --cipher-algo AES256 --output backup.tar.gz.gpg

# Upload encrypted archive
az storage blob upload \
  --account-name mystorageaccount \
  --container-name key-pairs-backup \
  --name prod/myapp/backup-$(date +%Y%m%d).tar.gz.gpg \
  --file backup.tar.gz.gpg

# Clean up local encrypted file
shred -u backup.tar.gz.gpg
```

### Backup Retention Policy

```bash
# Set lifecycle management policy
az storage account management-policy create \
  --account-name mystorageaccount \
  --policy @policy.json

# policy.json example:
{
  "rules": [{
    "enabled": true,
    "name": "retain-30-days",
    "type": "Lifecycle",
    "definition": {
      "actions": {
        "baseBlob": {
          "delete": { "daysAfterModificationGreaterThan": 30 }
        }
      },
      "filters": {
        "blobTypes": ["blockBlob"],
        "prefixMatch": ["key-pairs-backup/"]
      }
    }
  }]
}
```

### Backup Verification

```bash
# Verify backup integrity
az storage blob download \
  --account-name mystorageaccount \
  --container-name key-pairs-backup \
  --name prod/myapp/key-pair/private-key.asc \
  --file /tmp/verify-backup.asc

# Compare checksums
sha256sum ~/.gnupg/prod/myapp/key-pair/private-key.asc
sha256sum /tmp/verify-backup.asc

# Clean up
shred -u /tmp/verify-backup.asc
```

---

## Key Lifecycle Management

### Key Generation

```bash
# Document key creation
cat > ~/key-inventory.txt << EOF
Project: myapp
Environment: prod
Email: security@company.com
Created: $(date +%Y-%m-%d)
Expiry: $(date -d "+3 years" +%Y-%m-%d)
Purpose: Production data encryption
Location: ~/.gnupg/prod/myapp
Backup: Azure Blob (key-pairs-backup/prod/myapp)
EOF
```

### Key Rotation Schedule

| Environment | Rotation Frequency | Lead Time |
|-------------|-------------------|-----------|
| Production  | Annually          | 30 days   |
| Staging     | Every 6 months    | 14 days   |
| Development | Annually          | 7 days    |

### Key Rotation Process

```bash
#!/bin/bash
# rotate-gpg-key.sh

PROJECT="$1"
ENV="$2"
NEW_EMAIL="$3"
NEW_PASSKEY="$4"

# 1. Backup existing key
./backup_gpg_keypairs_to_azure.sh  # Select old key

# 2. Generate new key
./generate_gpg_keypairs.sh "$PROJECT" "$ENV" "$NEW_EMAIL" "$NEW_PASSKEY"

# 3. Re-encrypt sensitive files with new key
for file in *.gpg; do
    base="${file%.gpg}"
    
    # Decrypt with old key
    gpg --homedir ~/.gnupg/$ENV/${PROJECT}-old --decrypt "$file" > "$base"
    
    # Re-encrypt with new key
    gpg --batch --yes \
        --homedir ~/.gnupg/$ENV/$PROJECT \
        --encrypt -r "$NEW_EMAIL" \
        -o "${base}.new.gpg" \
        "$base"
    
    # Verify and replace
    mv "${base}.new.gpg" "$file"
    shred -u "$base"
done

# 4. Document rotation
echo "Rotated key for $PROJECT/$ENV on $(date)" >> ~/key-rotation.log

# 5. Archive old key (don't delete immediately)
mv ~/.gnupg/$ENV/$PROJECT ~/.gnupg/_archived/$ENV/${PROJECT}-$(date +%Y%m%d)
```

### Key Revocation

```bash
# Generate revocation certificate
gpg --homedir ~/.gnupg/prod/myapp \
    --gen-revoke security@company.com \
    > revocation-cert.asc

# Store revocation certificate securely (separate from private key)
chmod 600 revocation-cert.asc

# If key is compromised, import and publish revocation
gpg --import revocation-cert.asc
gpg --keyserver keyserver.ubuntu.com --send-keys <key-id>
```

---

## Incident Response

### Suspected Key Compromise

**Immediate Actions (within 1 hour):**

1. **Revoke Compromised Key**
   ```bash
   gpg --import revocation-cert.asc
   gpg --keyserver keyserver.ubuntu.com --send-keys <key-id>
   ```

2. **Rotate All Related Credentials**
   ```bash
   # Rotate Azure credentials
   az storage account keys renew \
     --account-name mystorageaccount \
     --key primary
   ```

3. **Delete Compromised Key**
   ```bash
   ./manage_gpg_keypairs.sh  # Delete affected keypair
   ```

4. **Audit Access Logs**
   ```bash
   # Check Azure storage access logs
   az storage blob list \
     --account-name mystorageaccount \
     --container-name '$logs' \
     --prefix "blob/$(date +%Y/%m/%d)"
   ```

**Follow-up Actions (within 24 hours):**

5. **Generate New Keypair**
   ```bash
   ./generate_gpg_keypairs.sh myapp prod security@company.com "NewSecurePass!"
   ```

6. **Re-encrypt All Data**
   ```bash
   # Decrypt with old key (if available) and re-encrypt
   for file in *.gpg; do
       # Process each encrypted file
       # See key rotation script above
   done
   ```

7. **Document Incident**
   - What was compromised
   - When it was detected
   - What actions were taken
   - Lessons learned

### Accidental Exposure

**If private key is accidentally committed to Git:**

```bash
# 1. Remove from Git history immediately
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch private-key.asc" \
  --prune-empty --tag-name-filter cat -- --all

# 2. Force push (if remote exists)
git push origin --force --all
git push origin --force --tags

# 3. Consider repository compromised - rotate all keys
# 4. Notify team members to re-clone repository
```

**If credentials are exposed in logs/chat:**

1. Revoke credentials immediately
2. Rotate all related secrets
3. Review access logs for unauthorized usage
4. Update logging configuration to prevent future exposure

---

## Compliance Considerations

### PCI DSS Compliance

- Use minimum 2048-bit RSA keys (4096 recommended)
- Rotate keys annually
- Maintain key inventory and access logs
- Encrypt keys at rest and in transit
- Implement multi-factor authentication for key access

### GDPR Compliance

- Document data retention policies
- Implement right to be forgotten (key deletion)
- Maintain audit logs for key operations
- Encrypt personal data with GPG
- Document cross-border data transfers

### SOC 2 Compliance

- Implement role-based access control (RBAC)
- Enable logging and monitoring
- Conduct regular security assessments
- Maintain incident response procedures
- Document security controls

### HIPAA Compliance

- Encrypt PHI using GPG
- Implement access controls and audit logs
- Use strong authentication
- Conduct regular risk assessments
- Maintain business associate agreements

---

## Security Checklist

### Before Generating Keys

- [ ] Strong passphrase prepared (16+ characters)
- [ ] Password manager configured for storage
- [ ] Destination directory permissions verified (700)
- [ ] Backup strategy defined
- [ ] Key rotation schedule documented

### After Generating Keys

- [ ] Private key permissions verified (600)
- [ ] Passphrase stored in password manager
- [ ] Public key fingerprint documented
- [ ] Revocation certificate generated and stored
- [ ] Keys backed up to secure location
- [ ] Key inventory updated

### Before Backing Up to Azure

- [ ] Azure credentials secured (not in plaintext)
- [ ] Storage encryption enabled
- [ ] Network restrictions configured
- [ ] Logging and monitoring enabled
- [ ] Lifecycle policies configured

### Regular Maintenance (Monthly)

- [ ] Review key inventory
- [ ] Check Azure storage costs
- [ ] Verify backup integrity
- [ ] Review access logs
- [ ] Update documentation

### Annual Review

- [ ] Rotate production keys
- [ ] Review and update security policies
- [ ] Conduct security assessment
- [ ] Update incident response procedures
- [ ] Train team on security practices

---

## Additional Resources

### Tools
- [GPG Documentation](https://gnupg.org/documentation/)
- [Azure Key Vault](https://docs.microsoft.com/azure/key-vault/)
- [1Password](https://1password.com/)
- [Bitwarden](https://bitwarden.com/)

### Security Standards
- [NIST Special Publication 800-57](https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final)
- [OWASP Key Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Key_Management_Cheat_Sheet.html)

### Training
- Security awareness training
- Incident response drills
- Key management procedures

---

**Last Updated**: December 8, 2025  
**Review Frequency**: Quarterly  
**Next Review**: March 8, 2026
