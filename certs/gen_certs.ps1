# Monitro — SSL Certificate Generation (Windows PowerShell)
# Run from the repo root as Administrator if needed
# Requires: OpenSSL for Windows (bundled with Git for Windows, or install from https://slproweb.com/products/Win32OpenSSL.html)

param(
    [int]$ValidDays = 3650
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "==> Monitro: Generating 4096-bit RSA certificates in: $ScriptDir" -ForegroundColor Cyan

# Step 1: CA private key
Write-Host "--> Generating CA private key (4096-bit RSA)..."
openssl genrsa -out ca.key 4096

# Step 2: CA self-signed cert
Write-Host "--> Generating CA self-signed certificate (valid $ValidDays days)..."
openssl req -new -x509 `
    -days $ValidDays `
    -key ca.key `
    -out ca.crt `
    -subj "/CN=Monitro Local CA/O=Monitro/OU=Local Development/C=US"

# Step 3: Server key and CSR
Write-Host "--> Generating server private key (4096-bit RSA)..."
openssl genrsa -out server.key 4096

Write-Host "--> Generating server CSR..."
openssl req -new `
    -key server.key `
    -out server.csr `
    -subj "/CN=localhost/O=Monitro/OU=Local/C=US"

# Step 4: Create SAN extension file
$sanExt = @"
[v3_req]
subjectAltName = IP:127.0.0.1, DNS:localhost, DNS:monitro.local
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
basicConstraints = CA:FALSE
"@
$sanExt | Out-File -FilePath san_ext.cnf -Encoding ASCII

# Step 5: Sign server cert
Write-Host "--> Signing server certificate with local CA..."
openssl x509 -req `
    -days $ValidDays `
    -in server.csr `
    -CA ca.crt `
    -CAkey ca.key `
    -CAcreateserial `
    -out server.crt `
    -extfile san_ext.cnf `
    -extensions v3_req

# Clean up temp files
Remove-Item -Force san_ext.cnf -ErrorAction SilentlyContinue

# Verify
Write-Host "--> Verifying certificate chain..."
openssl verify -CAfile ca.crt server.crt

Write-Host ""
Write-Host "Certificate generation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  CA certificate:     certs\ca.crt"
Write-Host "  Server certificate: certs\server.crt"
Write-Host "  Server key:         certs\server.key"
Write-Host ""
Write-Host "To trust the local CA on Windows:" -ForegroundColor Yellow
Write-Host "  certutil -addstore -f 'ROOT' certs\ca.crt"
