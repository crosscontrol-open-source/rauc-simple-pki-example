#!/bin/bash
#
# provision-device-optee.sh
#
# Provision the RAUC bundle-decryption key into the OP-TEE PKCS#11 token on a
# CrossControl CCL5+ device.
#
# Usage:
#   ./provision-device-optee.sh [user@host]
#   Default target is DEVICE_HOST from conf.sh.
#
# Run generate-enc-key.sh once before provisioning any devices.
#
# RAUC bundle encryption uses asymmetric CMS: the bundle's AES key is wrapped
# with an RSA public key. Only the device holding the matching private key can
# decrypt and install the bundle.
#
# This script handles the device provisioning step:
#   1. Copy the private key to the device over SSH (to /tmp only).
#   2. Import the private key into the OP-TEE PKCS#11 token.
#   3. Delete the plaintext key from the device.
#
# Re-running this script on an already-provisioned device replaces the key in
# the token and generates a new PKCS#11 PIN.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/conf.sh"

DEVICE="${1:-$DEVICE_HOST}"
KEY_FILE="$SCRIPT_DIR/$ENC_KEY_DIR/rauc-enc.key.pem"
CERT_FILE="$SCRIPT_DIR/$ENC_KEY_DIR/rauc-enc.cert.pem"
REMOTE_KEY="/tmp/rauc-enc.key.pem"
REMOTE_CERT="/tmp/rauc-enc.cert.pem"

SSH_OPTS=(-o StrictHostKeyChecking=no)
if [ -n "${DEVICE_SSH_KEY:-}" ] && [ -f "$DEVICE_SSH_KEY" ]; then
    SSH_OPTS+=(-i "$DEVICE_SSH_KEY")
fi

if [ ! -f "$KEY_FILE" ] || [ ! -f "$CERT_FILE" ]; then
    echo "Error: encryption key pair not found. Run generate-enc-key.sh first."
    echo "  Key : $KEY_FILE"
    echo "  Cert: $CERT_FILE"
    exit 1
fi

echo "Provisioning OP-TEE PKCS#11 encryption key on: $DEVICE"
echo "  Key : $KEY_FILE"
echo "  Cert: $CERT_FILE"

ssh "${SSH_OPTS[@]}" "$DEVICE" "sudo bash -s" << ENDSSH
set -e

PKCS11_MODULE="$PKCS11_MODULE"
TOKEN_LABEL="$PKCS11_TOKEN_LABEL"
SO_PIN="$PKCS11_SO_PIN"
PIN_ENV_FILE="$PKCS11_PIN_ENV_FILE"
ENC_KEY_ID="$PKCS11_ENC_KEY_ID"
ENC_KEY_LABEL="$PKCS11_ENC_KEY_LABEL"
ENC_CERT_LABEL="$PKCS11_ENC_CERT_LABEL"
KEY_DER="/tmp/rauc-enc.key.der"
CERT_DER="/tmp/rauc-enc.cert.der"
umask 077
trap 'rm -f "$REMOTE_KEY" "$REMOTE_CERT" "\$KEY_DER" "\$CERT_DER"; systemctl start rauc.service 2>/dev/null || true' EXIT

base64 -d > "$REMOTE_KEY" <<'END_ENC_KEY'
$(base64 < "$KEY_FILE")
END_ENC_KEY
base64 -d > "$REMOTE_CERT" <<'END_ENC_CERT'
$(base64 < "$CERT_FILE")
END_ENC_CERT

# Stop RAUC before re-initialising the token.
# pkcs11-tool --init-token fails with CKR_SESSION_EXISTS if RAUC holds an
# open session to the token.
systemctl stop rauc.service 2>/dev/null || true

mkdir -p /data/rauc
mkdir -p /data/tee
chmod 700 /data/tee

# Ensure the tee group exists so /dev/tee0 is accessible.
getent group tee     > /dev/null 2>&1 || groupadd tee
getent group teepriv > /dev/null 2>&1 || groupadd teepriv
if [ -c /dev/tee0 ]; then
    chown root:tee /dev/tee0
    chmod 660 /dev/tee0
fi

# Register the OP-TEE PKCS#11 library so pkcs11-tool and RAUC can find it.
mkdir -p /etc/pkcs11/modules
if [ ! -f /etc/pkcs11/modules/optee-pkcs11.module ]; then
    printf 'module: %s\ncritical: no\n' "\$PKCS11_MODULE" \
        > /etc/pkcs11/modules/optee-pkcs11.module
fi

# Generate a random device-unique PKCS#11 PIN and store it in the exact
# EnvironmentFile format consumed by rauc.service.
USER_PIN=\$(openssl rand -hex 16)
printf 'RAUC_PKCS11_PIN=%s\n' "\$USER_PIN" > "\$PIN_ENV_FILE"
chmod 600 "\$PIN_ENV_FILE"
rm -f /data/rauc/pkcs11-pin

# Initialize the token (clears all existing objects, making re-provisioning safe).
pkcs11-tool --module "\$PKCS11_MODULE" \
    --init-token --slot 0 --label "\$TOKEN_LABEL" --so-pin "\$SO_PIN" \
    > /dev/null 2>&1
pkcs11-tool --module "\$PKCS11_MODULE" \
    --init-pin --token-label "\$TOKEN_LABEL" \
    --so-pin "\$SO_PIN" --pin "\$USER_PIN" \
    > /dev/null 2>&1

openssl pkey -in "$REMOTE_KEY"  -out "\$KEY_DER"  -outform DER 2>/dev/null
openssl x509 -in "$REMOTE_CERT" -out "\$CERT_DER" -outform DER 2>/dev/null

# Remove any existing objects at this id before importing.
pkcs11-tool --module "\$PKCS11_MODULE" --token-label "\$TOKEN_LABEL" \
    --login --pin "\$USER_PIN" \
    --delete-object --type privkey --id "\$ENC_KEY_ID" > /dev/null 2>&1 || true
pkcs11-tool --module "\$PKCS11_MODULE" --token-label "\$TOKEN_LABEL" \
    --delete-object --type cert --id "\$ENC_KEY_ID" > /dev/null 2>&1 || true

pkcs11-tool --module "\$PKCS11_MODULE" \
    --token-label "\$TOKEN_LABEL" \
    --login --pin "\$USER_PIN" \
    --write-object "\$KEY_DER" --type privkey \
    --id "\$ENC_KEY_ID" --label "\$ENC_KEY_LABEL" \
    --usage-decrypt \
    > /dev/null 2>&1

pkcs11-tool --module "\$PKCS11_MODULE" \
    --token-label "\$TOKEN_LABEL" \
    --write-object "\$CERT_DER" --type cert \
    --id "\$ENC_KEY_ID" --label "\$ENC_CERT_LABEL" \
    > /dev/null 2>&1

ENDSSH

echo "Provisioning complete."
