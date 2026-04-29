#!/bin/bash
#
# generate-enc-key.sh
#
# Generate the RSA key pair used for RAUC bundle encryption.
#
# Run this ONCE before provisioning any devices. The resulting files are:
#
#   device-keys/rauc-enc.key.pem   Private key. Keep this on the build host.
#                                   It will be imported into each device's OP-TEE
#                                   during provisioning and must not be lost.
#
#   device-certs/rauc-enc.cert.pem Public certificate. Committed to the repo and
#                                   used by build-full-release-encrypted.sh to
#                                   encrypt bundles.
#
# Do NOT re-run this script unless you intend to rotate keys. After rotation
# all devices must be re-provisioned with provision-device-optee.sh before
# they can install newly encrypted bundles.
#
# Key strategy
# ------------
# This demo generates a single key shared by all devices (simplest approach).
# For production consider:
#
#   Batch keys:      One key pair per manufacturing batch. Rotate between batches.
#                    If a batch key is compromised, only that batch is affected.
#
#   Per-device keys: Maximum isolation. Each device has its own unique key pair.
#                    A compromised device does not affect any other device.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/conf.sh"

KEY_FILE="$SCRIPT_DIR/$ENC_KEY_DIR/rauc-enc.key.pem"
CERT_FILE="$SCRIPT_DIR/$ENC_KEY_DIR/rauc-enc.cert.pem"

mkdir -p "$SCRIPT_DIR/$ENC_KEY_DIR"
chmod 700 "$SCRIPT_DIR/$ENC_KEY_DIR"

if [ -f "$KEY_FILE" ] || [ -f "$CERT_FILE" ]; then
    echo "Encryption key pair already exists:"
    echo "  Key : $KEY_FILE"
    echo "  Cert: $CERT_FILE"
    echo
    echo "To replace: remove those files and re-run this script."
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
    -subj "/O=CrossControl/CN=V700 RAUC Bundle Encryption" \
    2>/dev/null

echo "Done."
echo
echo "  Private key : $KEY_FILE"
echo "  Public cert : $CERT_FILE"
echo
echo "Next steps:"
echo "  Provision devices : ./provision-device-optee.sh [user@host]"
