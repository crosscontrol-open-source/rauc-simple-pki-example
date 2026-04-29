
# Path to CrossControl SDK installation
SDK_INSTALL_PATH=/opt/V700

# ── OP-TEE PKCS#11 settings ───────────────────────────────────────────────────
# Used by provision-device-optee.sh when setting up the PKCS#11 token on the
# device, and embedded in the systemd drop-in so the RAUC service can access
# the decryption key at runtime.
# Change PINs before provisioning real hardware.
PKCS11_MODULE="/usr/lib/libckteec.so.0"  # Path on the target device
PKCS11_TOKEN_LABEL="rauc-token"
PKCS11_SO_PIN="12345678"                 # Security Officer PIN (used once, at token init)
PKCS11_USER_PIN="1234"                   # User PIN (used by RAUC service on every install)

# PKCS#11 slot for the bundle-encryption key.
# id=01 is reserved for the signing key; id=02 is used here for encryption.
PKCS11_ENC_KEY_ID="02"
PKCS11_ENC_KEY_LABEL="rauc-enc-key"
PKCS11_ENC_CERT_LABEL="rauc-enc-cert"

# Default SSH target used by provision-device-optee.sh
DEVICE_HOST="ccs@v700"

# Directory for the bundle-encryption key pair on the build host.
# Both the private key and the public certificate live here.
# The private key is imported into OP-TEE on the device during provisioning.
# The public certificate is used by the build host to encrypt bundles.
ENC_KEY_DIR="bundle-enc-key"    # rauc-enc.key.pem (private, keep secure)
                                 # rauc-enc.cert.pem (public, safe to commit)

