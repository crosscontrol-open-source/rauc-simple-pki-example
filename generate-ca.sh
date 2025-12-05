#!/bin/bash

set -xe

ORG="CrossControl AB"
CA="Provisioning CA"

# After the CRL expires, signatures cannot be verified anymore
CRL="-crldays 5000"

BASE="$(pwd)/openssl-ca"

if [ -e $BASE ]; then
  echo "$BASE already exists"
  exit 1
fi

mkdir -p $BASE/root/{private,certs,hash}
touch $BASE/root/index.txt
echo 01 > $BASE/root/serial

mkdir -p $BASE/release/{private,certs,hash}
touch $BASE/release/index.txt
echo 01 > $BASE/release/serial

mkdir -p $BASE/dev/{private,certs,hash}
touch $BASE/dev/index.txt
echo 01 > $BASE/dev/serial

cat > $BASE/openssl.cnf <<EOF
[ ca ]
default_ca      = CA_default            # The default ca section

[ CA_default ]

dir            = .                     # top dir
database       = \$dir/index.txt        # index file.
new_certs_dir  = \$dir/certs            # new certs dir

certificate    = \$dir/ca.cert.pem       # The CA cert
serial         = \$dir/serial           # serial no file
private_key    = \$dir/private/ca.key.pem# CA private key
RANDFILE       = \$dir/private/.rand    # random number file


default_startdate = 20250101000000Z
default_enddate = 20400101000000Z
default_crl_days= 5000                 # how long before next CRL, change to a realistic number if you use CRL
default_md     = sha256                # md to use

policy         = policy_any            # default policy
email_in_dn    = no                    # Don't add the email into cert DN

name_opt       = ca_default            # Subject name display option
cert_opt       = ca_default            # Certificate display option
copy_extensions = none                 # Don't copy extensions from request

[ policy_any ]
organizationName       = match
commonName             = supplied

[ req ]
default_bits           = 2048
distinguished_name     = req_distinguished_name
x509_extensions        = v3_leaf
encrypt_key = no
default_md = sha256

[ req_distinguished_name ]
commonName                     = Common Name (eg, YOUR name)
commonName_max                 = 64

[ v3_ca ]

subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer:always
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
extendedKeyUsage = critical, codeSigning

[ v3_inter ]

subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer:always
basicConstraints = critical, CA:TRUE,pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
extendedKeyUsage = critical, codeSigning

[ v3_leaf ]

subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer:always
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = critical, codeSigning
EOF

export OPENSSL_CONF=$BASE/openssl.cnf

echo "Root CA"
cd $BASE/root
openssl req -newkey rsa -keyout private/ca.key.pem -out ca.csr.pem -subj "/O=$ORG/CN=$ORG $CA Root"
openssl ca -batch -selfsign -extensions v3_ca -in ca.csr.pem -out ca.cert.pem -keyfile private/ca.key.pem

echo "Release Intermediate CA"
cd $BASE/release
openssl req -newkey rsa -keyout private/ca.key.pem -out ca.csr.pem -subj "/O=$ORG/CN=$ORG $CA Release"
cd $BASE/root
openssl ca -batch -extensions v3_inter -in $BASE/release/ca.csr.pem -out $BASE/release/ca.cert.pem

echo "Development Intermediate CA"
cd $BASE/dev
openssl req -newkey rsa -keyout private/ca.key.pem -out ca.csr.pem -subj "/O=$ORG/CN=$ORG $CA Development"
cd $BASE/root
openssl ca -batch -extensions v3_inter -in $BASE/dev/ca.csr.pem -out $BASE/dev/ca.cert.pem

echo "Developer Signing Keys 1&2"
cd $BASE/dev
openssl req -newkey rsa -keyout private/developer-1.pem -out developer-1.csr.pem -subj "/O=$ORG/CN=$ORG Developer-1"
openssl ca -batch -extensions v3_leaf -in developer-1.csr.pem -out developer-1.cert.pem
openssl req -newkey rsa -keyout private/developer-2.pem -out developer-2.csr.pem -subj "/O=$ORG/CN=$ORG Developer-2"
openssl ca -batch -extensions v3_leaf -in developer-2.csr.pem -out developer-2.cert.pem

echo "Release Signing Key"
cd $BASE/release
openssl req -newkey rsa -keyout private/release-1.pem -out release-1.csr.pem -subj "/O=$ORG/CN=$ORG Release-1"
openssl ca -batch -extensions v3_leaf -in release-1.csr.pem -out release-1.cert.pem
openssl rsa -aes256 -in private/release-1.pem -out private/release-1-encrypted.pem -passout pass:1111

echo "Generate CRL"
cd $BASE/root
openssl ca -gencrl $CRL -out crl.pem
openssl crl -in crl.pem -hash | head -n 1 | xargs -I {} cp crl.pem hash/{}.r0
openssl x509 -in ca.cert.pem -noout -hash | head -n 1 | xargs -I {} cp ca.cert.pem hash/{}.0
cd $BASE/release
openssl ca -gencrl $CRL -out crl.pem
openssl crl -in crl.pem -hash | head -n 1 | xargs -I {} cp crl.pem hash/{}.r0
openssl x509 -in ca.cert.pem -noout -hash | head -n 1 | xargs -I {} cp ca.cert.pem hash/{}.0
cd $BASE/dev
openssl ca -gencrl $CRL -out crl.pem
openssl crl -in crl.pem -hash | head -n 1 | xargs -I {} cp crl.pem hash/{}.r0
openssl x509 -in ca.cert.pem -noout -hash | head -n 1 | xargs -I {} cp ca.cert.pem hash/{}.0

echo "Build CA PEMs"
cd $BASE
cat root/ca.cert.pem > root-ca.pem
cat root/ca.cert.pem dev/ca.cert.pem > dev-ca.pem
cat root/ca.cert.pem release/ca.cert.pem > release-ca.pem




