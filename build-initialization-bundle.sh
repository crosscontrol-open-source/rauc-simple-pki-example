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

# Copy hash version of root ca and crl to a tar archive
tar -cf $PWD/$FOLDER_NAME/certs.tar -C openssl-ca/root/hash .

# Copy login key to be able to disable password login
cp $PWD/openssl-login/ccpilot-login-key.pub $PWD/$FOLDER_NAME/authorized_keys

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
