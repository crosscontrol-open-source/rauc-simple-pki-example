#!/bin/bash
source conf.sh

RAUC_BIN=$SDK_INSTALL_PATH/sysroots/x86_64-cclinuxsdk-linux/usr/bin/rauc
RAUC_CONF=$PWD/rauc-host.conf
DEMO_CC_CA_CERT=$PWD/cc-demo-keys/ca.cert.pem
DEMO_KEY=$PWD/cc-demo-keys/development-1.key.pem
DEMO_CERT=$PWD/cc-demo-keys/development-1.cert.pem

VERSION=1.0.0
BUNDLE_NAME="initialization-$VERSION.raucb"
FOLDER_NAME=customer-initialization-$VERSION

# Copy hash version of root CA and CRL for device keyring
tar -cf $FOLDER_NAME/certs.tar -C openssl-ca/root/hash .

# Copy SSH authorized key to enable keyless login
cp $PWD/openssl-login/ccpilot-login-key.pub $FOLDER_NAME/authorized_keys

# Generate the RAUC service drop-in.
# PKCS11_MODULE comes from conf.sh; the PIN is loaded directly from a
# root-only EnvironmentFile created during provisioning.
cat > $FOLDER_NAME/pkcs11-decrypt.conf << EOF
[Service]
Environment=RAUC_PKCS11_MODULE=$PKCS11_MODULE
EnvironmentFile=-$PKCS11_PIN_ENV_FILE
EOF

# Remove old bundle
rm -f $BUNDLE_NAME

# Create new bundle
$RAUC_BIN bundle \
    --conf=$RAUC_CONF \
    --keyring=$DEMO_CC_CA_CERT \
    --key=$DEMO_KEY \
    --cert=$DEMO_CERT \
    $FOLDER_NAME \
    $BUNDLE_NAME
