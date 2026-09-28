#!/bin/bash
#
# generate-enc-key.sh
#
# Generate the RSA key pair used for RAUC bundle encryption.
# Run this once before provisioning any devices.
#
# Output:
#   bundle-enc-key/rauc-enc.key.pem   Private key. Keep on the build host.
#                                      Imported into each device OP-TEE token
#                                      during provisioning. Do not lose this.
#   bundle-enc-key/rauc-enc.cert.pem  Public certificate. Committed to the repo,
#                                      used by build-full-release-encrypted.sh.
#
# Do not re-run unless rotating keys. After rotation all devices must be
# re-provisioned with provision-device-optee.sh before they can install new
# encrypted bundles.
#
# Key strategy note:
#   This demo generates a single key shared by all devices (simplest setup).
#   For production consider batch keys (one per manufacturing batch) or
#   per-device keys for maximum isolation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/conf.sh"

KEY_FILE="$SCRIPT_DIR/$ENC_KEY_DIR/rauc-enc.key.pem"
CERT_FILE="$SCRIPT_DIR/$ENC_KEY_DIR/rauc-enc.cert.pem"

mkdir -p "$SCRIPT_DIR/$ENC_KEY_DIR"
chmod 700 "$SCRIPT_DIR/$ENC_KEY_DIR"

if [ -f "$KEY_FILE" ] || [ -f "$CERT_FILE" ]; then
    echo "Encryption key pair already exists in $ENC_KEY_DIR/."
    echo "Remove those files and re-run to rotate keys."
    echo "Note: all provisioned devices must then be re-provisioned."
    exit 1
fi

echo "Generating RSA-4096 encryption key pair..."
openssl genrsa -out "$KEY_FILE" 4096 2>/dev/null
chmod 600 "$KEY_FILE"
openssl req -new -x509 \
    -key  "$KEY_FILE" \
    -out  "$CERT_FILE" \
    -days 36500 \
    -subj "$ENC_CERT_SUBJECT" \
    2>/dev/null

echo "Done. Key: $KEY_FILE  Cert: $CERT_FILE"
