#!/bin/bash
source ../conf.sh

RAUC_BIN=$SDK_INSTALL_PATH/sysroots/x86_64-cclinuxsdk-linux/usr/bin/rauc
RAUC_CONF=../rauc-host.conf
DEMO_CC_CA_CERT=../cc-demo-keys/ca.cert.pem
NEW_CA_CERT=../openssl-ca/dev-ca.pem
NEW_SIGN_KEY=../openssl-ca/dev/private/ca.key.pem
NEW_SIGN_CERT=../openssl-ca/dev/ca.cert.pem

# remove latest resigned bundle
rm -f resigned_$1

# set permission to extract bundle
chmod 0755 $1

$RAUC_BIN resign --no-verify \
        --conf=$RAUC_CONF \
	--cert=$NEW_SIGN_CERT \
	--key=$NEW_SIGN_KEY \
	--keyring=$DEMO_CC_CA_CERT \
	--signing-keyring=$NEW_CA_CERT \
	$1 \
	resigned_$1

