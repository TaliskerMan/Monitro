#!/usr/bin/env bash
# ==============================================================================
# Monitro — Local SSL Certificate Generator (macOS / Linux)
# ==============================================================================
# Generates a 4096-bit RSA local CA and a server certificate signed by it.
# The server cert covers localhost and 127.0.0.1.
#
# Usage:
#   chmod +x certs/gen_certs.sh
#   ./certs/gen_certs.sh
#
# After running, optionally trust the CA in your OS:
#   macOS:  sudo security add-trusted-cert -d -r trustRoot \
#             -k /Library/Keychains/System.keychain certs/ca.crt
#   Linux:  sudo cp certs/ca.crt /usr/local/share/ca-certificates/monitro-ca.crt
#             && sudo update-ca-certificates
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CA_KEY="ca.key"
CA_CRT="ca.crt"
SERVER_KEY="server.key"
SERVER_CSR="server.csr"
SERVER_CRT="server.crt"
DAYS=3650   # 10 years for local dev cert

echo "==> Monitro: Generating 4096-bit RSA certificates in: $SCRIPT_DIR"

# ------------------------------------------------------------------------------
# Step 1: Create local CA
# ------------------------------------------------------------------------------
echo "--> Generating CA private key (4096-bit RSA)..."
openssl genrsa -out "$CA_KEY" 4096

echo "--> Generating CA self-signed certificate (valid ${DAYS} days)..."
openssl req -new -x509 \
  -days "$DAYS" \
  -key "$CA_KEY" \
  -out "$CA_CRT" \
  -subj "/CN=Monitro Local CA/O=Monitro/OU=Local Development/C=US"

# ------------------------------------------------------------------------------
# Step 2: Create server key and CSR
# ------------------------------------------------------------------------------
echo "--> Generating server private key (4096-bit RSA)..."
openssl genrsa -out "$SERVER_KEY" 4096

echo "--> Generating server CSR..."
openssl req -new \
  -key "$SERVER_KEY" \
  -out "$SERVER_CSR" \
  -subj "/CN=localhost/O=Monitro/OU=Local/C=US"

# ------------------------------------------------------------------------------
# Step 3: Sign the server cert with the local CA
# ------------------------------------------------------------------------------
echo "--> Signing server certificate with local CA..."
openssl x509 -req \
  -days "$DAYS" \
  -in "$SERVER_CSR" \
  -CA "$CA_CRT" \
  -CAkey "$CA_KEY" \
  -CAcreateserial \
  -out "$SERVER_CRT" \
  -extfile <(cat <<EOF
[v3_req]
subjectAltName = IP:127.0.0.1, DNS:localhost, DNS:monitro.local
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
basicConstraints = CA:FALSE
EOF
)

# ------------------------------------------------------------------------------
# Step 4: Verify
# ------------------------------------------------------------------------------
echo "--> Verifying certificate chain..."
openssl verify -CAfile "$CA_CRT" "$SERVER_CRT"

# Protect private keys
chmod 600 "$CA_KEY" "$SERVER_KEY"

echo ""
echo "✓ Certificate generation complete!"
echo ""
echo "  CA certificate:     certs/ca.crt"
echo "  Server certificate: certs/server.crt"
echo "  Server key:         certs/server.key  (chmod 600)"
echo ""
echo "To trust the local CA on macOS, run:"
echo "  sudo security add-trusted-cert -d -r trustRoot \\"
echo "    -k /Library/Keychains/System.keychain certs/ca.crt"
echo ""
echo "To trust on Linux:"
echo "  sudo cp certs/ca.crt /usr/local/share/ca-certificates/monitro-ca.crt"
echo "  sudo update-ca-certificates"
