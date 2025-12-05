#!/bin/bash
source conf.sh

RAUC_BIN=$SDK_INSTALL_PATH/sysroots/x86_64-cclinuxsdk-linux/usr/bin/rauc
RAUC_CONF=$PWD/rauc-host.conf
DEMO_CC_CA_CERT=$PWD/cc-demo-keys/ca.cert.pem
DEMO_KEY=$PWD/cc-demo-keys/development-1.key.pem
DEMO_CERT=$PWD/cc-demo-keys/development-1.cert.pem

VERSION=1.0.0
BUNDLE_NAME="install-package-$VERSION.raucb"
FOLDER_NAME=release-full-$VERSION

# Remove old bundle
rm $BUNDLE_NAME

# Create new bundle
$RAUC_BIN bundle \
    --conf=$RAUC_CONF \
    --keyring=$DEMO_CC_CA_CERT \
    --key=$DEMO_KEY \
    --cert=$DEMO_CERT \
    $FOLDER_NAME \
    $BUNDLE_NAME
