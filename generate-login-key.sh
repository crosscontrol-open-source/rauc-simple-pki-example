#!/bin/bash

set -xe

BASE="$(pwd)/openssl-login"

mkdir -p ${BASE}/
cd ${BASE}/
echo "Generating RSA 4096 login key pair..."

ssh-keygen -t rsa -b 4096 -f ccpilot-login-key -C "ccpilot-login"



