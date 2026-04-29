#!/bin/bash
#
# provision-device-optee.sh
#
# Provision the RAUC bundle-decryption key into the OP-TEE PKCS#11 token on a
# CrossControl V700 device.
#
# Usage:
#   ./provision-device-optee.sh [user@host]
#   Default target is DEVICE_HOST from conf.sh.
#
# Prerequisites
# -------------
# Run generate-enc-key.sh once before provisioning any devices. It creates:
#   device-keys/rauc-enc.key.pem   private key (stays on build host)
#   device-certs/rauc-enc.cert.pem public cert (used by build host to encrypt bundles)
#
# Overview
# --------
# RAUC bundle encryption uses asymmetric CMS: the bundle's AES key is wrapped
# with an RSA public key. Only the device holding the matching private key can
# decrypt and install the bundle.
#
# This script handles the device provisioning step:
#   1. Copy the private key to the device over SSH (temporary, /tmp only).
#   2. Import the private key into the OP-TEE PKCS#11 token (CAAM-backed secure
#      storage). Once imported, the key never leaves the TEE in plaintext.
#   3. Delete the plaintext key from the device.
#
# Re-running this script on an already-provisioned device replaces the key in
# the token (idempotent).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/conf.sh"

DEVICE="${1:-$DEVICE_HOST}"
KEY_FILE="$SCRIPT_DIR/$ENC_KEY_DIR/rauc-enc.key.pem"
CERT_FILE="$SCRIPT_DIR/$ENC_KEY_DIR/rauc-enc.cert.pem"
REMOTE_KEY="/tmp/rauc-enc.key.pem"
REMOTE_CERT="/tmp/rauc-enc.cert.pem"

if [ ! -f "$KEY_FILE" ] || [ ! -f "$CERT_FILE" ]; then
    echo "Error: encryption key pair not found. Run generate-enc-key.sh first."
    echo "  Expected key : $KEY_FILE"
    echo "  Expected cert: $CERT_FILE"
    exit 1
fi

echo "Provisioning OP-TEE PKCS#11 encryption key on: $DEVICE"
echo

# ── Step 1: Verify key pair exists on build host ─────────────────────────────
echo "Using key pair:"
echo "  Key : $KEY_FILE"
echo "  Cert: $CERT_FILE"
echo

# ── Step 2: Copy key material to device /tmp ─────────────────────────────────
# Copied to /tmp only — not written to persistent storage on the device.
echo "Copying key to $DEVICE:/tmp (temporary)..."
scp -o StrictHostKeyChecking=no -q "$KEY_FILE"  "$DEVICE:$REMOTE_KEY"
scp -o StrictHostKeyChecking=no -q "$CERT_FILE" "$DEVICE:$REMOTE_CERT"

# ── Step 3: Import key into OP-TEE on device ─────────────────────────────────

# All commands run as root via sudo. The OP-TEE secure storage is backed by
# /data/tee which is encrypted by CAAM. Once the key is imported, the private
# key material is only accessible through the PKCS#11 API — it cannot be read
# back in plaintext.
echo "Importing key into OP-TEE on $DEVICE..."
ssh -o StrictHostKeyChecking=no "$DEVICE" "sudo bash -s" << ENDSSH
set -e

PKCS11_MODULE="$PKCS11_MODULE"
TOKEN_LABEL="$PKCS11_TOKEN_LABEL"
SO_PIN="$PKCS11_SO_PIN"
USER_PIN="$PKCS11_USER_PIN"
ENC_KEY_ID="$PKCS11_ENC_KEY_ID"
ENC_KEY_LABEL="$PKCS11_ENC_KEY_LABEL"
ENC_CERT_LABEL="$PKCS11_ENC_CERT_LABEL"
KEY_DER="/tmp/rauc-enc.key.der"
CERT_DER="/tmp/rauc-enc.cert.der"

# Create OP-TEE storage directories if they do not exist.
# /data is the writable partition; /data/tee is the secure storage root.
mkdir -p /data/tee /data/caam
chmod 700 /data/tee

# The tee group is required to access /dev/tee0 as non-root.
getent group tee     > /dev/null 2>&1 || groupadd tee
getent group teepriv > /dev/null 2>&1 || groupadd teepriv
if [ -c /dev/tee0 ]; then
    chown root:tee /dev/tee0
    chmod 660 /dev/tee0
fi

# Register the OP-TEE PKCS#11 library with p11-kit so that tools like
# pkcs11-tool and RAUC can locate the module by its token label.
# /etc on this device is an overlayfs backed by /data/cc-etc, so this
# file persists across reboots.
mkdir -p /etc/pkcs11/modules
if [ ! -f /etc/pkcs11/modules/optee-pkcs11.module ]; then
    printf 'module: %s\ncritical: no\n' "\$PKCS11_MODULE" \
        > /etc/pkcs11/modules/optee-pkcs11.module
fi

# Initialize the PKCS#11 token inside OP-TEE. Only runs once per device;
# subsequent runs skip this block.
if pkcs11-tool --module "\$PKCS11_MODULE" --list-slots 2>/dev/null \
        | grep -q "\$TOKEN_LABEL"; then
    echo "  PKCS#11 token already initialized."
else
    echo "  Initializing PKCS#11 token..."
    pkcs11-tool --module "\$PKCS11_MODULE" \
        --init-token --slot 0 --label "\$TOKEN_LABEL" --so-pin "\$SO_PIN" \
        > /dev/null 2>&1
    pkcs11-tool --module "\$PKCS11_MODULE" \
        --init-pin --token-label "\$TOKEN_LABEL" \
        --so-pin "\$SO_PIN" --pin "\$USER_PIN" \
        > /dev/null 2>&1
fi

# pkcs11-tool requires DER format for import.
openssl pkey -in "$REMOTE_KEY"  -out "\$KEY_DER"  -outform DER 2>/dev/null
openssl x509 -in "$REMOTE_CERT" -out "\$CERT_DER" -outform DER 2>/dev/null

# Remove any existing objects at this slot ID so re-provisioning is clean.
pkcs11-tool --module "\$PKCS11_MODULE" --token-label "\$TOKEN_LABEL" \
    --login --pin "\$USER_PIN" \
    --delete-object --type privkey --id "\$ENC_KEY_ID" > /dev/null 2>&1 || true
pkcs11-tool --module "\$PKCS11_MODULE" --token-label "\$TOKEN_LABEL" \
    --delete-object --type cert --id "\$ENC_KEY_ID" > /dev/null 2>&1 || true

# Import the private key. The key is marked for decrypt usage and stored as
# sensitive — it cannot be exported after import.
echo "  Importing private key into OP-TEE..."
pkcs11-tool --module "\$PKCS11_MODULE" \
    --token-label "\$TOKEN_LABEL" \
    --login --pin "\$USER_PIN" \
    --write-object "\$KEY_DER" --type privkey \
    --id "\$ENC_KEY_ID" --label "\$ENC_KEY_LABEL" \
    --usage-decrypt \
    > /dev/null 2>&1

# Import the certificate alongside the key. RAUC uses it to match the correct
# recipient entry when a bundle is encrypted for multiple recipients.
echo "  Importing certificate into OP-TEE..."
pkcs11-tool --module "\$PKCS11_MODULE" \
    --token-label "\$TOKEN_LABEL" \
    --write-object "\$CERT_DER" --type cert \
    --id "\$ENC_KEY_ID" --label "\$ENC_CERT_LABEL" \
    > /dev/null 2>&1

# Remove the plaintext copies from the device. From this point on the private
# key exists only inside OP-TEE secure storage (CAAM-encrypted /data/tee).
rm -f "$REMOTE_KEY" "$REMOTE_CERT" "\$KEY_DER" "\$CERT_DER"
echo "  Plaintext key removed from device."
ENDSSH

# ── Done ─────────────────────────────────────────────────────────────────────
echo
echo "Provisioning complete."
echo
echo "  Public cert (for encrypting bundles on build host):"
echo "    $CERT_FILE"
echo
echo "  PKCS#11 URI (used by RAUC on the device for decryption):"
echo "    pkcs11:token=$PKCS11_TOKEN_LABEL;id=%$PKCS11_ENC_KEY_ID;type=private"
echo
echo "Next steps:"
echo "  Deploy RAUC config : ./build-initialization-bundle.sh"
echo "  Build enc bundle   : ./build-full-release-encrypted.sh"
