
# Path to CrossControl SDK installation
SDK_INSTALL_PATH=/opt/v700

# OP-TEE PKCS#11 settings
# Used by provision-device-optee.sh when setting up the PKCS#11 token on the device.
PKCS11_MODULE="/usr/lib/libckteec.so.0"  # Path on the target device
PKCS11_TOKEN_LABEL="rauc-token"
PKCS11_SO_PIN="12345678"                 # Administrative token PIN used only during token initialization

# EnvironmentFile consumed directly by rauc.service.
# Generated once at provisioning with openssl rand; root-only, device-unique,
# and persistent across reboots.
PKCS11_PIN_ENV_FILE="/data/rauc/pkcs11-pin.env"

# PKCS#11 slot for the bundle-encryption key.
# id=01 is reserved for the signing key; id=02 is used here for encryption.
PKCS11_ENC_KEY_ID="02"
PKCS11_ENC_KEY_LABEL="rauc-enc-key"
PKCS11_ENC_CERT_LABEL="rauc-enc-cert"

# Default SSH target used by provision-device-optee.sh
DEVICE_HOST="ccs@v700"
# SSH identity file for device access.
# On a fresh device (before the initialization bundle is installed), password
# auth is used and this can be left empty. After the initialization bundle
# replaces password login with key-based auth, set this to the private key.
DEVICE_SSH_KEY="$PWD/openssl-login/ccpilot-login-key"

# Directory for the bundle-encryption key pair on the build host.
# The private key is imported into OP-TEE on the device during provisioning.
# The public certificate is used by the build host to encrypt bundles.
ENC_KEY_DIR="bundle-enc-key"    # rauc-enc.key.pem (private, keep secure)
                                 # rauc-enc.cert.pem (public, safe to commit)
