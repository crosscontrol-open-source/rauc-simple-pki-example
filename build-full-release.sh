#!/bin/bash
source conf.sh

RAUC_BIN=$SDK_INSTALL_PATH/sysroots/x86_64-cclinuxsdk-linux/usr/bin/rauc
RAUC_CONF=$PWD/rauc-host.conf
ROOT_CA_CERT=$PWD/openssl-ca/root-ca.pem
DEV_SIGN_KEY=$PWD/openssl-ca/dev/private/developer-1.pem
DEV_SIGN_CERT=$PWD/openssl-ca/dev/developer-1.cert.pem
DEV_INTERMEDIATE=$PWD/openssl-ca/dev/ca.cert.pem

VERSION=1.0.0
BUNDLE_NAME="install-package-$VERSION.raucb"

rm -f $BUNDLE_NAME

$RAUC_BIN bundle \
    --conf=$RAUC_CONF \
    --keyring=$ROOT_CA_CERT \
    --key=$DEV_SIGN_KEY \
    --cert=$DEV_SIGN_CERT \
    --intermediate=$DEV_INTERMEDIATE \
    release-full-$VERSION \
    $BUNDLE_NAME
