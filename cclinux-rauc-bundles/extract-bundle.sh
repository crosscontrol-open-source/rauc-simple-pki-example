#!/bin/bash
source ../conf.sh

RAUC_BIN=$SDK_INSTALL_PATH/sysroots/x86_64-cclinuxsdk-linux/usr/bin/rauc
RAUC_CONF=../rauc-host.conf
DEMO_CC_CA_CERT=../cc-demo-keys/ca.cert.pem

# remove latest folder
rm -rf latest

# set permission to extract bundle
chmod 0755 $1

$RAUC_BIN extract $1 \
    --conf=$RAUC_CONF \
    --keyring=$DEMO_CC_CA_CERT \
    $PWD/latest

