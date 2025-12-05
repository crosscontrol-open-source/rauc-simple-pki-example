#!/bin/bash
source ../conf.sh

RAUC_BIN=$SDK_INSTALL_PATH/sysroots/x86_64-cclinuxsdk-linux/usr/bin/rauc
RAUC_CONF=../rauc-host.conf
NEW_CA_CERT=../cc-demo-keys/ca.cert.pem
NEW_SIGN_KEY=../cc-demo-keys/development-1.key.pem
NEW_SIGN_CERT=../cc-demo-keys/development-1.cert.pem

# remove latest resigned bundle
rm -f resigned_$1

# set permission to extract bundle
chmod 0755 $1

$RAUC_BIN resign --no-verify \
        --conf=$RAUC_CONF \
	--cert=$NEW_SIGN_CERT \
	--key=$NEW_SIGN_KEY \
	--signing-keyring=$NEW_CA_CERT \
	$1 \
	resigned_$1

