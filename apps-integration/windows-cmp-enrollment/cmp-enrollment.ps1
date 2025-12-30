# ============================================================
# Win7-friendly: CSR via certreq + CMP enroll to EJBCA (RA Mode HMAC) + Install
# ============================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$Fqdn = "ejbca.example.test",

    [Parameter(Mandatory=$false)]
    [string]$Alias = "device",

    [Parameter(Mandatory=$false)]
    [string]$SharedSecret = "foo123",

    [Parameter(Mandatory=$false)]
    [string]$SubjectDN = "CN=device01.test,OU=IoT Devices,O=Keyfactor,C=US",

    [Parameter(Mandatory=$false)]
    [string]$ChallengePassword = "foo123",

    [Parameter(Mandatory=$false)]
    [string]$CaCertFile = "it-sub-ca.cer",

    [Parameter(Mandatory=$false)]
    [ValidateSet("2048", "3072", "4096")]
    [string]$KeyLength = "2048",

    [Parameter(Mandatory=$false)]
    [bool]$IncludeDnsSan = $true,

    [Parameter(Mandatory=$false)]
    [bool]$CleanupArtifacts = $true,

    [Parameter(Mandatory=$false)]
    [switch]$DebugLog,

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

$ErrorActionPreference = "Stop"

# --------------------------
# Help
# --------------------------
if ($Help) {
    Write-Host @"
EJBCA CMP Enrollment Script
============================

DESCRIPTION:
    Generate a CSR via certreq, enroll for a certificate with the CSR using EJBCA CMP protocol,
    and installs the issued certificate to the Windows Local Machine Personal certificate store.

USAGE:
    .\ejbca_cmp_ps.ps1 [OPTIONS]

OPTIONS:
    -Fqdn <string>
        EJBCA server FQDN (Fully Qualified Domain Name)
        Do NOT include http:// or https:// - it will be added automatically
        Example: ejbca.example.com
        Default: ejbca.example.test

    -Alias <string>
        CMP alias configured in EJBCA
        Default: device

    -SharedSecret <string>
        RA shared secret for HMAC authentication
        Default: foo123

    -SubjectDN <string>
        Full X.500 Distinguished Name for the certificate subject
        Format: CN=<common name>,OU=<org unit>,O=<org>,C=<country>
        Example: "CN=device01.example.com,OU=IoT Devices,O=MyOrg,C=US"
        Default: CN=device01.test,OU=IoT Devices,O=Keyfactor,C=US

    -ChallengePassword <string>
        Challenge password for the certificate request
        Default: foo123

    -CaCertFile <string>
        Filename of the CA certificate used for CMP response signature verification
        The file should be in the current working directory
        Default: it-sub-ca.cer

    -KeyLength <string>
        RSA key length in bits
        Valid values: 2048, 3072, 4096
        Default: 2048

    -IncludeDnsSan <bool>
        Include DNS Subject Alternative Name (SAN) extension in the certificate request
        The DNS SAN will be set to the CN value from the Subject DN
        Valid values: $true, $false
        Default: $true

    -CleanupArtifacts <bool>
        Remove all generated files after successful certificate enrollment
        Files removed: INF, REQ, PEM, P7B, and stdout/stderr logs
        The certificate is already installed in Windows certificate store
        Valid values: $true, $false
        Default: $false

    -DebugLog
        Enable verbose console output (all details to console)
        Without this flag, only progress messages are shown on console
        All output is always logged to the audit log file regardless of this flag
        Default: $false (minimal console output)

    -Help
        Display this help message and exit

EXAMPLES:
    # Use all default values
    .\ejbca_cmp_ps.ps1

    # Enroll a certificate with custom values
    .\ejbca_cmp_ps.ps1 -Fqdn "ejbca.example.com" -Alias "my-device" -SharedSecret "mysecret123" -SubjectDN "CN=device01,OU=IoT,O=MyOrg,C=US"

    # Override only specific parameters
    .\ejbca_cmp_ps.ps1 -SubjectDN "CN=test-device,OU=Testing,O=Test,C=US" -ChallengePassword "testpass"

    # Use a different CA certificate file
    .\ejbca_cmp_ps.ps1 -CaCertFile "iot-ca.pem"

    # Use a 4096-bit RSA key
    .\ejbca_cmp_ps.ps1 -KeyLength 4096 -SubjectDN "CN=secure-device,OU=Security,O=MyOrg,C=US"

    # Generate certificate without DNS SAN extension
    .\ejbca_cmp_ps.ps1 -IncludeDnsSan `$false -SubjectDN "CN=non-dns-device,OU=Special,O=MyOrg,C=US"

    # Enroll and clean up all artifacts after successful installation
    .\ejbca_cmp_ps.ps1 -CleanupArtifacts `$true -SubjectDN "CN=clean-device,OU=Production,O=MyOrg,C=US"

    # Enable verbose console output for troubleshooting
    .\ejbca_cmp_ps.ps1 -DebugLog -SubjectDN "CN=debug-device,OU=Testing,O=MyOrg,C=US"

REQUIREMENTS:
    - OpenSSL must be installed at: C:\Program Files\OpenSSL-Win64\bin\openssl.exe
      Download from: https://slproweb.com/products/Win32OpenSSL.html
      (Install the Win64 OpenSSL package)
    - CA certificate file that issued the certficate in the current working directory
    - Windows certreq.exe (built-in Windows tool)
    - CA chain is installed into Windows CAPI

OUTPUT FILES:
    Per-enrollment files (prefixed with CN from Subject DN):
    - <CN>-request.inf       : Certificate request configuration
    - <CN>-request.req       : Raw CSR file
    - <CN>-request.pem       : PEM-formatted CSR
    - <CN>-issued-cert.pem   : Issued certificate
    - <CN>-enroll.p7b        : PKCS#7 certificate bundle

    Persistent audit log (appends for all enrollments):
    - ejbca-cmp-enrollment.log : Audit trail of all enrollment sessions

"@
    exit 0
}

# --------------------------
# Inputs (configurable via CLI flags)
# --------------------------

# Extract CN from SubjectDN first (needed for $Ref and file naming)
$cnMatch = [regex]::Match($SubjectDN, 'CN=([^,]+)')
$cnValue = if ($cnMatch.Success) { $cnMatch.Groups[1].Value } else { "default" }
# Sanitize CN for use in filename (remove invalid characters)
$sanitizedCN = $cnValue -replace '[\\/:*?"<>|]', '_'

# Construct the full URL from FQDN (always use http://)
$EjbcaBaseUrl   = "http://$Fqdn"
$CmpAlias       = $Alias
$RaSharedSecret = $SharedSecret
$Ref            = $cnValue  # Use CN from Subject DN as the reference

# Use LocalMachine keyset for machine certificate store
$UseMachineKeySet = $true

# --------------------------
# Local paths (current folder)
# --------------------------
$BasePath = Get-Location
$OpenSsl  = "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"

# CMP response signature verification cert (per your alias: Response Protection = signature)
$CmpResponseSignerPem = Join-Path $BasePath $CaCertFile

# TLS trust anchor for the HTTPS server certificate (OPTIONAL but often required)
# If you get TLS verify errors, set this to the issuing CA PEM of the *web server* cert.
# You can start by pointing it at ManagementCA.pem if that's also the TLS issuer.
$TlsTrustedPem = $null  # e.g. Join-Path $BasePath "WebTlsIssuerCA.pem"

$infPath = Join-Path $BasePath "$sanitizedCN-request.inf"
$csrRaw  = Join-Path $BasePath "$sanitizedCN-request.req"
$csrPem  = Join-Path $BasePath "$sanitizedCN-request.pem"
$certPem = Join-Path $BasePath "$sanitizedCN-issued-cert.pem"
$p7bPath = Join-Path $BasePath "$sanitizedCN-enroll.p7b"
$logFile = Join-Path $BasePath "ejbca-cmp-enrollment.log"

# Log file is persistent and appends for audit trail
# Do not remove or initialize - each run appends to the log

# Function to write to both console and log file
function Write-Log {
    param(
        [string]$Message,
        [switch]$AlwaysShow  # Always show on console regardless of DebugLog setting
    )

    # Always write to log file
    Add-Content -Path $logFile -Value $Message -Encoding utf8

    # Write to console only if DebugLog is enabled or AlwaysShow is set
    if ($DebugLog -or $AlwaysShow) {
        Write-Host $Message
    }
}

$CmpPath = "/ejbca/publicweb/cmp/$CmpAlias"

Write-Log "" -AlwaysShow
Write-Log "================================================================================" -AlwaysShow
Write-Log "NEW ENROLLMENT SESSION - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -AlwaysShow
Write-Log "================================================================================" -AlwaysShow
Write-Log "Subject DN:     $SubjectDN" -AlwaysShow
Write-Log "Working folder: $BasePath" -AlwaysShow
Write-Log "OpenSSL:        $OpenSsl" -AlwaysShow
Write-Log "CMP URL base:   $EjbcaBaseUrl" -AlwaysShow
Write-Log "CMP Path:       $CmpPath" -AlwaysShow
Write-Log "CMP Ref:        $Ref" -AlwaysShow
Write-Log "CMP Alias:      $CmpAlias" -AlwaysShow
Write-Log "Key Length:     $KeyLength bits" -AlwaysShow
Write-Log "Include DNS SAN: $IncludeDnsSan" -AlwaysShow
Write-Log "MachineKeySet:  $UseMachineKeySet" -AlwaysShow
Write-Log "Cleanup After:  $CleanupArtifacts" -AlwaysShow
Write-Log "Audit log:      $logFile" -AlwaysShow
Write-Log "" -AlwaysShow

if (!(Test-Path $OpenSsl)) { throw "openssl.exe not found at: $OpenSsl" }
if (!(Test-Path $CmpResponseSignerPem)) { throw "CMP response signer PEM not found: $CmpResponseSignerPem" }
if ($TlsTrustedPem -and !(Test-Path $TlsTrustedPem)) { throw "TLS trusted PEM not found: $TlsTrustedPem" }

function Get-AsciiPrefix([byte[]]$b, [int]$n) {
    $n2 = [Math]::Min($n, $b.Length)
    return [Text.Encoding]::ASCII.GetString($b, 0, $n2)
}

function Ensure-CsrPem {
    param(
        [Parameter(Mandatory=$true)][string]$InputCsrPath,
        [Parameter(Mandatory=$true)][string]$OutputPemPath,
        [Parameter(Mandatory=$true)][string]$OpenSslPath
    )

    $raw = [IO.File]::ReadAllBytes($InputCsrPath)
    $prefixHex = ("{0:X2} {1:X2} {2:X2} {3:X2} {4:X2}" -f $raw[0],$raw[1],$raw[2],$raw[3],$raw[4])
    $prefixAsc = Get-AsciiPrefix $raw 16

    Write-Log ("CSR prefix HEX:  {0}" -f $prefixHex)
    Write-Log ("CSR prefix ASCII:'{0}'" -f $prefixAsc)

    if ($raw[0] -eq 0x2D -and $raw[1] -eq 0x2D -and $raw[2] -eq 0x2D) {
        Write-Log "Detected PEM CSR; copying..."
        Copy-Item -Force $InputCsrPath $OutputPemPath
        return
    }

    if ($raw[0] -eq 0x30) {
        Write-Log "Detected DER CSR; converting DER -> PEM..."
        & $OpenSslPath req -in $InputCsrPath -inform DER -out $OutputPemPath -outform PEM
        return
    }

    Write-Log "CSR not obvious DER/PEM; trying certutil decode then DER->PEM..."
    $tmpDer = Join-Path (Split-Path $OutputPemPath -Parent) "request.tmp.der"
    if (Test-Path $tmpDer) { Remove-Item -Force $tmpDer }

    $decodedOk = $true
    try { certutil.exe -decode $InputCsrPath $tmpDer | Out-Null } catch { $decodedOk = $false }

    if ($decodedOk -and (Test-Path $tmpDer)) {
        & $OpenSslPath req -in $tmpDer -inform DER -out $OutputPemPath -outform PEM
        Remove-Item -Force $tmpDer -ErrorAction SilentlyContinue
        return
    }

    throw "Unable to normalize CSR to PEM. CSR does not look like DER/PEM/base64-text."
}

# --------------------------
# [1/4] Generate CSR
# --------------------------
# Build INF template based on whether DNS SAN is included
if ($IncludeDnsSan) {
    $infTemplate = @'
[Version]
Signature="$Windows NT$"

[NewRequest]
Subject = "{0}"
KeySpec = 1
KeyLength = {4}
Exportable = TRUE
MachineKeySet = {2}
ProviderType = 24
ProviderName = "Microsoft Enhanced RSA and AES Cryptographic Provider"
RequestType = PKCS10
HashAlgorithm = sha256

[Extensions]
2.5.29.17 = "{{text}}"
_continue_ = "dns={1}&"

[RequestAttributes]
challengePassword = "{3}"
'@
} else {
    $infTemplate = @'
[Version]
Signature="$Windows NT$"

[NewRequest]
Subject = "{0}"
KeySpec = 1
KeyLength = {4}
Exportable = TRUE
MachineKeySet = {2}
ProviderType = 24
ProviderName = "Microsoft Enhanced RSA and AES Cryptographic Provider"
RequestType = PKCS10
HashAlgorithm = sha256

[RequestAttributes]
challengePassword = "{3}"
'@
}

$machineKeySetValue = if ($UseMachineKeySet) { "TRUE" } else { "FALSE" }
$infContent = $infTemplate -f $SubjectDN, $cnValue, $machineKeySetValue, $ChallengePassword, $KeyLength
Set-Content -Path $infPath -Value $infContent -Encoding ascii

Write-Log "[1/4] Generating CSR via certreq..." -AlwaysShow
foreach ($f in @($csrRaw, $csrPem, $certPem, $p7bPath)) { if (Test-Path $f) { Remove-Item -Force $f } }

# Temporary files for stdout/stderr capture
$tempStdout = Join-Path $BasePath "$sanitizedCN-certreq-new.stdout.tmp"
$tempStderr = Join-Path $BasePath "$sanitizedCN-certreq-new.stderr.tmp"

$p = Start-Process -FilePath "certreq.exe" `
  -ArgumentList @("-new", "`"$infPath`"", "`"$csrRaw`"") `
  -NoNewWindow `
  -RedirectStandardOutput $tempStdout `
  -RedirectStandardError $tempStderr `
  -PassThru

$null = $p.WaitForExit()

# Log certreq output
if (Test-Path $tempStdout) {
    $stdoutContent = Get-Content $tempStdout -Raw
    if ($stdoutContent) {
        Write-Log "certreq stdout:"
        Write-Log $stdoutContent
    }
    Remove-Item -Force $tempStdout
}
if (Test-Path $tempStderr) {
    $stderrContent = Get-Content $tempStderr -Raw
    if ($stderrContent) {
        Write-Log "certreq stderr:"
        Write-Log $stderrContent
    }
    Remove-Item -Force $tempStderr
}

if (!(Test-Path $csrRaw)) { throw "CSR was not created: $csrRaw" }
Write-Log "CSR created: $csrRaw"
Write-Log ""

# --------------------------
# [2/4] Normalize CSR -> PEM
# --------------------------
Write-Log "[2/4] Preparing CSR PEM for OpenSSL..." -AlwaysShow
Ensure-CsrPem -InputCsrPath $csrRaw -OutputPemPath $csrPem -OpenSslPath $OpenSsl

Write-Log "CSR PEM: $csrPem"
$csrSubject = & $OpenSsl req -in $csrPem -noout -subject 2>&1
Write-Log $csrSubject
Write-Log ""

# --------------------------
# [3/4] CMP enroll
# --------------------------
Write-Log "[3/4] Enrolling via CMP (P10CR) over HTTP..." -AlwaysShow

# Build OpenSSL CMP args
$args = @(
  "cmp",
  "-cmd", "p10cr",
  "-server", $EjbcaBaseUrl,
  "-path", $CmpPath,
  "-srvcert", $CmpResponseSignerPem,  # CMP response signature verification
  "-ref", $Ref,
  "-secret", ("pass:" + $RaSharedSecret),
  "-csr", $csrPem,
  "-certout", $certPem,
  "-verbosity", "7"
)

# Optional TLS trust anchor for HTTPS server certificate validation
if ($TlsTrustedPem) {
  $args += @("-tls_trusted", $TlsTrustedPem)
}

# Execute and capture output
$cmpOut = & $OpenSsl @args 2>&1
$cmpOutText = $cmpOut | Out-String
Write-Log $cmpOutText

if (!(Test-Path $certPem)) {
  $errorMsg = "CMP did not produce a certificate output file: $certPem`n`nCMP Output:`n$cmpOutText`n`nTROUBLESHOOTING:`nCheck the EJBCA logs for additional information on why the enrollment may have failed.`nCommon causes: incorrect shared secret, alias not found, certificate profile restrictions, or CA signing issues."
  Write-Log $errorMsg
  throw $errorMsg
}

Write-Log "Issued cert saved: $certPem"
Write-Log ""

# --------------------------
# [4/4] Install issued cert
# --------------------------
Write-Log "[4/4] Converting issued cert to PKCS#7 and installing to LocalMachine\Personal..." -AlwaysShow
& $OpenSsl crl2pkcs7 -nocrl -certfile $certPem -outform DER -out $p7bPath
if (!(Test-Path $p7bPath)) { throw "PKCS#7 was not created: $p7bPath" }

# Install to Local Machine Personal certificate store
# When MachineKeySet=TRUE, certreq -accept automatically uses LocalMachine store
certreq.exe -accept $p7bPath | Out-Null

Write-Log "Certificate installed to: LocalMachine\Personal (Computer Certificate Store)"

# --------------------------
# Cleanup artifacts if requested
# --------------------------
if ($CleanupArtifacts) {
    Write-Log ""
    Write-Log "Cleaning up artifacts..."

    $artifactsToRemove = @($infPath, $csrRaw, $csrPem, $certPem, $p7bPath)
    $removedCount = 0

    foreach ($artifact in $artifactsToRemove) {
        if (Test-Path $artifact) {
            try {
                Remove-Item -Force $artifact -ErrorAction Stop
                Write-Log "  Removed: $artifact"
                $removedCount++
            } catch {
                Write-Log "  Warning: Could not remove $artifact - $_"
            }
        }
    }

    Write-Log ""
    Write-Log "Done. Removed $removedCount artifact file(s)."
    Write-Log "Certificate is installed in: LocalMachine\Personal (Computer Certificate Store)"
} else {
    Write-Log ""
    Write-Log "Done. Artifacts:"
    Write-Log "  INF       : $infPath"
    Write-Log "  CSR (raw) : $csrRaw"
    Write-Log "  CSR (PEM) : $csrPem"
    Write-Log "  CERT (PEM): $certPem"
    Write-Log "  P7B       : $p7bPath"
}

Write-Log "" -AlwaysShow
Write-Log "================================================================================" -AlwaysShow
Write-Log "ENROLLMENT SESSION COMPLETED - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -AlwaysShow
Write-Log "================================================================================" -AlwaysShow