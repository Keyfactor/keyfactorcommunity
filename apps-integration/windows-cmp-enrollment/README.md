# Windows CMP Enrollment Script

PowerShell script for automated certificate enrollment via EJBCA CMP (Certificate Management Protocol) on Windows systems, including Windows 7.

## Overview

This script automates the complete certificate enrollment workflow:
1. Generates a Certificate Signing Request (CSR) using Windows `certreq`
2. Enrolls the certificate via EJBCA CMP protocol with HMAC authentication
3. Installs the issued certificate into the selected Windows certificate store (Local Machine, Current User, or both)
4. Optionally exports the certificate with private key to a PFX file

The script is designed to work with EJBCA in CA or RA Mode using HMAC-based authentication and supports both modern and legacy Windows systems.

## Features

- **Windows 7+ Compatible**: Uses `certreq` for CSR generation, compatible with older Windows versions
- **CMP Protocol**: Industry-standard certificate enrollment via EJBCA CMP
- **HMAC Authentication**: Secure RA mode authentication with shared secrets
- **Flexible Configuration**: Extensive command-line parameters for customization
- **DNS SAN Support**: Optional DNS Subject Alternative Name extension
- **Configurable Key Sizes**: Support for 2048, 3072, and 4096-bit RSA keys
- **Flexible Certificate Store**: Install to Local Machine, Current User, or both stores simultaneously
- **PFX Export**: Export certificate with private key to password-protected PFX file
- **Configurable PFX Encryption**: Choose between AES-256 (default) or Triple DES encryption
- **Audit Logging**: Persistent audit trail of all enrollment sessions
- **Artifact Management**: Optional cleanup of intermediate files
- **Debug Mode**: Verbose logging for troubleshooting

## Prerequisites

### Required Software

1. **OpenSSL for Windows**
   - Must be installed at: `C:\Program Files\OpenSSL-Win64\bin\openssl.exe`
   - Download from: [https://slproweb.com/products/Win32OpenSSL.html](https://slproweb.com/products/Win32OpenSSL.html)
   - Install the Win64 OpenSSL package

2. **Windows certreq.exe**
   - Built-in Windows tool (included with all Windows versions)

### Required Files

- **CA Certificate File**: The CA certificate used for CMP response signature verification
  - Default filename: `sub-ca.pem`
  - Must be in the same directory as the script or specify path with `-CaCertFile`

### System Requirements

- CA certificate chain must be installed in Windows CAPI (Certificate API)
- Network access to the EJBCA server
- Administrator privileges (required when installing to Local Machine store; not required for Current User store only)

## Installation

1. Download the script to your desired directory
2. Install OpenSSL for Windows to the default location
3. Place the CA certificate file in the same directory
4. Ensure the CA chain is installed in Windows certificate store

## Usage

### Basic Usage

```powershell
.\cmp-enrollment.ps1
```

This will use all default values to enroll a certificate.

### Common Scenarios

#### Enroll with Custom Settings

```powershell
.\cmp-enrollment.ps1 -Fqdn "ejbca.example.com" `
                     -Alias "my-device" `
                     -SharedSecret "mysecret123" `
                     -SubjectDN "CN=device01,OU=IoT,O=MyOrg,C=US"
```

#### Use 4096-bit RSA Key

```powershell
.\cmp-enrollment.ps1 -KeyLength 4096 `
                     -SubjectDN "CN=secure-device,OU=Security,O=MyOrg,C=US"
```

#### Enroll Without DNS SAN Extension

```powershell
.\cmp-enrollment.ps1 -IncludeDnsSan $false `
                     -SubjectDN "CN=non-dns-device,OU=Special,O=MyOrg,C=US"
```

#### Clean Up Artifacts After Installation

```powershell
.\cmp-enrollment.ps1 -CleanupArtifacts $true `
                     -SubjectDN "CN=clean-device,OU=Production,O=MyOrg,C=US"
```

#### Export Certificate to PFX (Default AES-256 Encryption)

```powershell
.\cmp-enrollment.ps1 -ExportPfx `
                     -SubjectDN "CN=device01,OU=IoT,O=MyOrg,C=US"
```

#### Export Certificate to PFX with Triple DES Encryption

```powershell
.\cmp-enrollment.ps1 -ExportPfx `
                     -PfxEncryption 3des `
                     -SubjectDN "CN=legacy-device,OU=IoT,O=MyOrg,C=US"
```

#### Export Certificate to PFX at Specific Location

```powershell
.\cmp-enrollment.ps1 -ExportPfx `
                     -PfxOutputPath "C:\Certificates\device01.pfx" `
                     -SubjectDN "CN=device01,OU=IoT,O=MyOrg,C=US"
```

#### Export Certificate to PFX with Password (Automated Scenarios)

```powershell
.\cmp-enrollment.ps1 -ExportPfx `
                     -PfxPassword "MySecurePassword123" `
                     -SubjectDN "CN=device01,OU=IoT,O=MyOrg,C=US"
```

**Note**: Providing passwords via command line is less secure and should only be used in automated scenarios where interactive prompts are not possible.

#### Install to Current User Personal Store

```powershell
.\cmp-enrollment.ps1 -CertificateStore CurrentUser `
                     -SubjectDN "CN=user-device,OU=Users,O=MyOrg,C=US"
```

No administrator privileges required. The private key is stored in the current user's key store.

#### Install to Both Local Machine and Current User Stores

```powershell
.\cmp-enrollment.ps1 -CertificateStore Both `
                     -SubjectDN "CN=shared-device,OU=IoT,O=MyOrg,C=US"
```

The certificate and private key are installed to both `LocalMachine\Personal` and `CurrentUser\Personal`. Requires administrator privileges.

#### Enable Verbose Debug Logging

```powershell
.\cmp-enrollment.ps1 -DebugLog `
                     -SubjectDN "CN=debug-device,OU=Testing,O=MyOrg,C=US"
```

#### Display Help

```powershell
.\cmp-enrollment.ps1 -Help
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Fqdn` | string | `ejbca.example.test` | EJBCA server FQDN (without http:// or https://) |
| `-Alias` | string | `device` | CMP alias configured in EJBCA |
| `-SharedSecret` | string | `foo123` | RA shared secret for HMAC authentication |
| `-SubjectDN` | string | `CN=device01.test,OU=IoT Devices,O=Keyfactor,C=US` | Full X.500 Distinguished Name |
| `-ChallengePassword` | string | `foo123` | Challenge password for the certificate request |
| `-CaCertFile` | string | `it-sub-ca.cer` | Filename of the CA certificate for CMP response verification |
| `-KeyLength` | string | `2048` | RSA key length (Valid: 2048, 3072, 4096) |
| `-IncludeDnsSan` | bool | `$true` | Include DNS Subject Alternative Name extension |
| `-CleanupArtifacts` | bool | `$true` | Remove generated files after successful enrollment |
| `-ExportPfx` | switch | `$false` | Export certificate and private key to PFX file |
| `-PfxEncryption` | string | `aes256` | PFX encryption algorithm (Valid: aes256, 3des) |
| `-PfxOutputPath` | string | `""` | Full path for PFX file (default: script directory) |
| `-PfxPassword` | string | `""` | Password for PFX file (default: interactive prompt) |
| `-CertificateStore` | string | `LocalMachine` | Certificate store to install into (Valid: `LocalMachine`, `CurrentUser`, `Both`) |
| `-DebugLog` | switch | `$false` | Enable verbose console output |
| `-Help` | switch | - | Display help message and exit |

## Output Files

### Per-Enrollment Files

Files are prefixed with the CN (Common Name) from the Subject DN:

- `<CN>-request.inf` - Certificate request configuration
- `<CN>-request.req` - Raw CSR file
- `<CN>-request.pem` - PEM-formatted CSR
- `<CN>-issued-cert.pem` - Issued certificate in PEM format
- `<CN>-enroll.p7b` - PKCS#7 certificate bundle
- `<CN>.pfx` - Password-protected PFX/PKCS#12 file (only if `-ExportPfx` is specified)

**Note**: If `-CleanupArtifacts $true` is specified, intermediate files (INF, REQ, PEM, P7B) are automatically removed after successful enrollment. The PFX file is retained if exported.

### Audit Log

- `ejbca-cmp-enrollment.log` - Persistent audit trail of all enrollment sessions
  - This file is never automatically deleted
  - Each enrollment session appends to this log
  - Contains timestamps, configuration, and detailed output

## How It Works

### Step 1: Generate CSR
- Creates an INF configuration file with certificate request parameters
- Uses Windows `certreq` to generate a Certificate Signing Request
- Supports configurable RSA key lengths (2048/3072/4096 bits)
- Optionally includes DNS SAN extension based on CN value

### Step 2: Normalize CSR to PEM Format
- Detects CSR format (DER, PEM, or base64-encoded)
- Converts to PEM format if necessary using OpenSSL
- Validates CSR subject and attributes

### Step 3: CMP Enrollment
- Submits CSR to EJBCA via CMP P10CR command
- Uses HMAC authentication with shared secret
- Verifies CMP response signature using provided CA certificate
- Receives and saves issued certificate

### Step 4: Install Certificate
- Converts issued certificate to PKCS#7 format
- Installs to the certificate store(s) specified by `-CertificateStore`:
  - **LocalMachine** (default): installs to `LocalMachine\Personal`; private key stored in machine key store
  - **CurrentUser**: installs to `CurrentUser\Personal`; private key stored in user key store
  - **Both**: installs to `LocalMachine\Personal` first, then copies the certificate and private key into `CurrentUser\Personal` via a temporary PFX. Uses `Export/Import-PfxCertificate` on Windows 8+, or `certutil -exportPFX` / `certutil -user -importPFX` on Windows 7
- Associates certificate with private key generated in Step 1

### Step 5: Export to PFX (Optional)
- If `-ExportPfx` is specified, calculates the thumbprint of the issued certificate
- Finds the installed certificate in the certificate store by thumbprint (more reliable than Subject DN matching)
- Prompts for a password to protect the PFX file (or uses provided password)
- Exports certificate with private key using selected encryption (AES-256 or Triple DES)
- Saves to specified location or script directory
- Optionally cleans up intermediate files

## Certificate Storage

The target store is controlled by the `-CertificateStore` parameter:

| Value | Store Location | Key Storage | Privileges Required |
|-------|---------------|-------------|---------------------|
| `LocalMachine` (default) | `LocalMachine\Personal` | Machine key store (all users) | Administrator |
| `CurrentUser` | `CurrentUser\Personal` | User key store (current user only) | None |
| `Both` | `LocalMachine\Personal` and `CurrentUser\Personal` | Both key stores | Administrator |

When `Both` is selected, the script installs to `LocalMachine\Personal` first (via `certreq -accept`), then copies the certificate and private key into `CurrentUser\Personal` using a temporary PFX with a randomly generated password. On Windows 7, where `Export-PfxCertificate` and `Import-PfxCertificate` are unavailable, `certutil -exportPFX` and `certutil -user -importPFX` are used instead.

## Troubleshooting

### Common Issues

#### OpenSSL Not Found
```
Error: openssl.exe not found at: C:\Program Files\OpenSSL-Win64\bin\openssl.exe
```
**Solution**: Install OpenSSL for Windows from [https://slproweb.com/products/Win32OpenSSL.html](https://slproweb.com/products/Win32OpenSSL.html)

#### CA Certificate Not Found
```
Error: CMP response signer PEM not found: it-sub-ca.cer
```
**Solution**: Place the CA certificate file in the same directory as the script, or specify the correct path with `-CaCertFile`

#### CMP Enrollment Failed
```
Error: CMP did not produce a certificate output file
```
**Possible Causes**:
- Incorrect shared secret
- CMP alias not found in EJBCA configuration
- Certificate profile restrictions
- CA signing issues
- Subject DN doesn't match End Entity profile

**Solution**:
1. Enable debug logging with `-DebugLog`
2. Check EJBCA server logs for detailed error messages
3. Verify CMP alias configuration in EJBCA
4. Verify shared secret matches EJBCA configuration
5. Ensure Subject DN matches End Entity profile requirements

#### Permission Denied
**Solution**: Run PowerShell as Administrator when using `-CertificateStore LocalMachine` or `-CertificateStore Both`. If administrator privileges are not available, use `-CertificateStore CurrentUser` instead.

#### PFX Export - Certificate Not Found
```
WARNING: Could not find certificate with thumbprint: ...
```
**Cause**: The certificate lookup uses the thumbprint from the issued certificate file, which is more reliable than Subject DN matching (EJBCA may reorder DN components).

**Solution**:
1. Verify the certificate was successfully installed using `certlm.msc` (Local Machine certificate manager)
2. Check the audit log for any errors during certificate installation
3. The script automatically handles DN reordering by using thumbprint matching instead of Subject DN matching

**Note**: The script uses thumbprint-based certificate lookup to avoid issues with Subject DN ordering differences between the request and the issued certificate.

### Debug Logging

Enable verbose logging for troubleshooting:

```powershell
.\cmp-enrollment.ps1 -DebugLog
```

This will output all details to the console and the audit log file.

### Viewing the Audit Log

All enrollment sessions are logged to `ejbca-cmp-enrollment.log`:

```powershell
Get-Content .\ejbca-cmp-enrollment.log -Tail 100
```

## Security Considerations

- **Shared Secrets**: The shared secret is passed via command line and may be visible in process listings. Consider alternative secure methods for production use.
- **Challenge Password**: Similar to shared secret, consider secure input methods.
- **PFX Password**:
  - By default, you'll be prompted to enter a password interactively (most secure)
  - The `-PfxPassword` parameter allows providing the password via command line for automation
  - **WARNING**: Command-line passwords may be visible in process listings and shell history
  - Only use `-PfxPassword` in automated scenarios where interactive prompts are not possible
  - Always use strong passwords to protect the private key
- **PFX Encryption**: AES-256 (default) is recommended for better security. Triple DES is provided for legacy system compatibility only.
- **PFX File Storage**: PFX files contain private keys. Store them in secure locations with appropriate access controls. Consider encrypting the storage location.
- **Artifact Cleanup**: Use `-CleanupArtifacts $true` to remove intermediate files containing sensitive information. PFX files are retained when exported.
- **Audit Trail**: The audit log contains enrollment details. Secure this file appropriately.
- **Transport Security**: By default, the script uses HTTP for CMP communication. Configure EJBCA and modify the script for HTTPS in production environments.

## EJBCA Configuration

This script requires the following EJBCA configuration:

1. **CMP Alias**: Configure a CMP alias in EJBCA
   - Set to RA or CA Mode
   - Configure HMAC-based authentication
   - Set Response Protection to "signature"

2. **End Entity Profile**: Create or configure an End Entity profile
   - Must allow the Subject DN components you plan to use
   - Configure allowed key algorithms and key lengths
   - Set certificate profile reference

3. **Certificate Profile**: Configure certificate profile
   - Set validity period
   - Configure key usage and extended key usage
   - Set allowed extensions (including SAN if needed)

4. **CA Configuration**: Ensure CA is operational
   - CA must be in "ACTIVE" status
   - CA chain must include the certificate specified in `-CaCertFile`

## Examples

### IoT Device Enrollment

```powershell
.\cmp-enrollment.ps1 -Fqdn "iot-pki.company.com" `
                     -Alias "iot-devices" `
                     -SharedSecret "iot-secret-2024" `
                     -SubjectDN "CN=sensor-01.iot.company.com,OU=IoT Sensors,O=Company,C=US" `
                     -KeyLength 2048 `
                     -CleanupArtifacts $true
```

### High-Security Server Certificate

```powershell
.\cmp-enrollment.ps1 -Fqdn "pki.company.com" `
                     -Alias "servers" `
                     -SharedSecret "server-secret-2024" `
                     -SubjectDN "CN=web-server-01.company.com,OU=Web Servers,O=Company,C=US" `
                     -KeyLength 4096 `
                     -CaCertFile "server-ca.cer" `
                     -CleanupArtifacts $true
```

### IoT Device with PFX Export

```powershell
.\cmp-enrollment.ps1 -Fqdn "iot-pki.company.com" `
                     -Alias "iot-devices" `
                     -SharedSecret "iot-secret-2024" `
                     -SubjectDN "CN=sensor-02.iot.company.com,OU=IoT Sensors,O=Company,C=US" `
                     -ExportPfx `
                     -PfxOutputPath "C:\Certificates\sensor-02.pfx" `
                     -CleanupArtifacts $true
```

### Legacy System with Triple DES PFX

```powershell
.\cmp-enrollment.ps1 -Fqdn "pki.company.com" `
                     -Alias "legacy" `
                     -SharedSecret "legacy-secret-2024" `
                     -SubjectDN "CN=legacy-system-01.company.com,OU=Legacy Systems,O=Company,C=US" `
                     -ExportPfx `
                     -PfxEncryption 3des `
                     -KeyLength 2048
```

### Automated PFX Export (CI/CD or Scripted Deployment)

```powershell
.\cmp-enrollment.ps1 -Fqdn "pki.company.com" `
                     -Alias "automation" `
                     -SharedSecret "automation-secret-2024" `
                     -SubjectDN "CN=automated-device-01.company.com,OU=Automation,O=Company,C=US" `
                     -ExportPfx `
                     -PfxPassword "AutomatedP@ssw0rd!" `
                     -PfxOutputPath "C:\Deploy\certificates\device.pfx" `
                     -CleanupArtifacts $true
```

**Note**: This example shows automated deployment. Ensure secrets are managed securely (e.g., Azure Key Vault, AWS Secrets Manager, etc.) rather than hardcoded.

### User Certificate (No Admin Required)

```powershell
.\cmp-enrollment.ps1 -Fqdn "pki.company.com" `
                     -Alias "users" `
                     -SharedSecret "user-secret-2024" `
                     -SubjectDN "CN=john.doe,OU=Users,O=Company,C=US" `
                     -CertificateStore CurrentUser `
                     -CleanupArtifacts $true
```

### Shared Workstation (Both Stores)

```powershell
.\cmp-enrollment.ps1 -Fqdn "pki.company.com" `
                     -Alias "workstations" `
                     -SharedSecret "ws-secret-2024" `
                     -SubjectDN "CN=workstation-01.company.com,OU=Workstations,O=Company,C=US" `
                     -CertificateStore Both `
                     -CleanupArtifacts $true
```

### Testing and Debugging

```powershell
.\cmp-enrollment.ps1 -Fqdn "pki-test.company.com" `
                     -Alias "test" `
                     -SharedSecret "test123" `
                     -SubjectDN "CN=test-device-01,OU=Testing,O=Company,C=US" `
                     -DebugLog `
                     -CleanupArtifacts $false
```

## License

This script is part of the Keyfactor Community repository. Please refer to the repository license for usage terms.

## Support

For issues, questions, or contributions:
- GitHub Issues: [keyfactor-community](https://github.com/keyfactor/keyfactor-community)
- EJBCA Documentation: [https://docs.keyfactor.com/ejbca](https://docs.keyfactor.com/ejbca)

## Contributing

Contributions are welcome! Please submit pull requests or issues to the Keyfactor Community repository.

## Related Resources

- [EJBCA CMP Documentation](https://docs.keyfactor.com/ejbca/ejbca-protocols/cmp)
- [OpenSSL CMP Commands](https://www.openssl.org/docs/man3.0/man1/openssl-cmp.html)
- [Windows Certificate Services](https://docs.microsoft.com/en-us/windows-server/networking/core-network-guide/cncg/server-certs/install-the-certification-authority)
