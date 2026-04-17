#!/bin/bash
#
# Automated workflow for building RAUC bundles signed with customer-specific keys.
# Combines: generate-ca.sh + generate-login-key.sh + generate-appfs-ext4.sh +
#           build-initialization-bundle.sh + extract-bundle.sh + build-full-release.sh
#
set -euo pipefail

# --- Defaults ---
VERSION="1.0.0"
APPFS_SIZE_MB=800
BUNDLE_PATH=""

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Build RAUC bundles using customer-specific keys (full production workflow).
Produces two bundles:
  1. initialization-<version>.raucb  — replaces demo certs on the display (install first)
  2. install-package-<version>.raucb — full OS + app update signed with your keys

Options:
  --version VERSION    Bundle version (default: $VERSION)
  --appfs-size SIZE    Appfs image size in MB (default: $APPFS_SIZE_MB)
  --bundle PATH        Path to CrossControl .raucb bundle file
                       (auto-detected from cclinux-rauc-bundles/ if only one exists)
  --generate-ca        Generate new CA hierarchy (will prompt if openssl-ca/ already exists)
  --generate-login-key Generate new SSH login key pair (will prompt if openssl-login/ already exists)
  --skip-init          Skip building the initialization bundle
  -h, --help           Show this help message

Prerequisites:
  - CrossControl SDK installed (path configured in conf.sh)
  - Application content placed in appfs/ folder (minimum 4KB total)
  - CrossControl rootfs bundle (.raucb) placed in cclinux-rauc-bundles/
  - manifest.raucm configured for your target device in release-full-<version>/
EOF
    exit 0
}

GENERATE_CA=false
GENERATE_LOGIN_KEY=false
SKIP_INIT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift 2 ;;
        --appfs-size) APPFS_SIZE_MB="$2"; shift 2 ;;
        --bundle) BUNDLE_PATH="$2"; shift 2 ;;
        --generate-ca) GENERATE_CA=true; shift ;;
        --generate-login-key) GENERATE_LOGIN_KEY=true; shift ;;
        --skip-init) SKIP_INIT=true; shift ;;
        -h|--help) usage ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; usage ;;
    esac
done

RELEASE_DIR="release-full-$VERSION"
INIT_DIR="customer-initialization-$VERSION"
INSTALL_BUNDLE="install-package-$VERSION.raucb"
INIT_BUNDLE="initialization-$VERSION.raucb"

# --- Source SDK configuration ---
source conf.sh
RAUC_BIN="$SDK_INSTALL_PATH/sysroots/x86_64-cclinuxsdk-linux/usr/bin/rauc"
RAUC_CONF="$PWD/rauc-host.conf"
DEMO_CA_CERT="$PWD/cc-demo-keys/ca.cert.pem"
DEMO_KEY="$PWD/cc-demo-keys/development-1.key.pem"
DEMO_CERT="$PWD/cc-demo-keys/development-1.cert.pem"

echo -e "${BLUE}=== RAUC Bundle Builder (Custom Keys) ===${NC}"
echo -e "Version: ${VERSION} | Appfs size: ${APPFS_SIZE_MB}MB"
echo ""

# --- Prerequisite checks ---
echo -e "${YELLOW}Checking prerequisites...${NC}"

if [ ! -x "$RAUC_BIN" ]; then
    echo -e "${RED}Error: RAUC binary not found at $RAUC_BIN${NC}"
    echo "Install the CrossControl SDK and update SDK_INSTALL_PATH in conf.sh"
    exit 1
fi

if [ ! -d "appfs" ]; then
    echo -e "${RED}Error: 'appfs/' folder does not exist${NC}"
    echo "Create this folder and add your application content."
    exit 1
fi

if [ ! -d "$RELEASE_DIR" ] || [ ! -f "$RELEASE_DIR/manifest.raucm" ]; then
    echo -e "${RED}Error: '$RELEASE_DIR/manifest.raucm' not found${NC}"
    echo "Create the release folder with a valid manifest for your target device."
    exit 1
fi

if [ "$SKIP_INIT" = false ] && { [ ! -d "$INIT_DIR" ] || [ ! -f "$INIT_DIR/manifest.raucm" ]; }; then
    echo -e "${RED}Error: '$INIT_DIR/manifest.raucm' not found${NC}"
    echo "Create the initialization folder with a valid manifest and custom_handler.sh."
    exit 1
fi

# Auto-detect .raucb bundle
if [ -z "$BUNDLE_PATH" ]; then
    shopt -s nullglob
    RAUCB_FILES=(cclinux-rauc-bundles/*.raucb)
    shopt -u nullglob

    if [ ${#RAUCB_FILES[@]} -eq 0 ]; then
        echo -e "${RED}Error: No .raucb files found in cclinux-rauc-bundles/${NC}"
        echo "Download a rootfs bundle from CrossControl and place it there."
        exit 1
    elif [ ${#RAUCB_FILES[@]} -eq 1 ]; then
        BUNDLE_PATH="${RAUCB_FILES[0]}"
        echo -e "  Auto-detected bundle: ${GREEN}$(basename "$BUNDLE_PATH")${NC}"
    else
        echo -e "${RED}Error: Multiple .raucb files found in cclinux-rauc-bundles/:${NC}"
        printf '  %s\n' "${RAUCB_FILES[@]}"
        echo "Specify which one to use with --bundle PATH"
        exit 1
    fi
fi

if [ ! -f "$BUNDLE_PATH" ]; then
    echo -e "${RED}Error: Bundle file not found: $BUNDLE_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}All prerequisites OK${NC}"
echo ""

# --- Step 1: CA hierarchy ---
TOTAL_STEPS=5
if [ "$SKIP_INIT" = true ]; then
    TOTAL_STEPS=4
fi
STEP=1

echo -e "${BLUE}[Step $STEP/$TOTAL_STEPS] CA hierarchy...${NC}"
if [ -d "openssl-ca" ]; then
    if [ "$GENERATE_CA" = true ]; then
        echo -e "${YELLOW}  openssl-ca/ already exists. Regenerating will replace all keys and certificates.${NC}"
        read -r -p "  Delete existing CA and generate new one? [y/N] " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            rm -rf openssl-ca
            bash generate-ca.sh
            echo -e "${GREEN}  CA hierarchy regenerated in openssl-ca/${NC}"
        else
            echo -e "  Keeping existing CA"
        fi
    else
        echo -e "${GREEN}  Using existing openssl-ca/${NC}"
    fi
elif [ "$GENERATE_CA" = true ]; then
    bash generate-ca.sh
    echo -e "${GREEN}  CA hierarchy created in openssl-ca/${NC}"
else
    echo -e "${RED}Error: openssl-ca/ not found${NC}"
    echo "Run with --generate-ca to create a new CA hierarchy, or run generate-ca.sh manually."
    exit 1
fi
STEP=$((STEP + 1))
echo ""

# --- Step 2: SSH login key ---
echo -e "${BLUE}[Step $STEP/$TOTAL_STEPS] SSH login key pair...${NC}"
if [ -d "openssl-login" ] && [ -f "openssl-login/ccpilot-login-key.pub" ]; then
    if [ "$GENERATE_LOGIN_KEY" = true ]; then
        echo -e "${YELLOW}  openssl-login/ already exists. Regenerating will replace the login key pair.${NC}"
        read -r -p "  Delete existing key and generate new one? [y/N] " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            rm -rf openssl-login
            bash generate-login-key.sh
            echo -e "${GREEN}  Login key pair regenerated in openssl-login/${NC}"
        else
            echo -e "  Keeping existing login key"
        fi
    else
        echo -e "${GREEN}  Using existing openssl-login/${NC}"
    fi
elif [ "$GENERATE_LOGIN_KEY" = true ]; then
    bash generate-login-key.sh
    echo -e "${GREEN}  Login key pair created in openssl-login/${NC}"
else
    echo -e "${RED}Error: openssl-login/ccpilot-login-key.pub not found${NC}"
    echo "Run with --generate-login-key to create a new key pair, or run generate-login-key.sh manually."
    exit 1
fi
STEP=$((STEP + 1))
echo ""

# --- Step 3: Generate appfs.ext4 and extract rootfs ---
echo -e "${BLUE}[Step $STEP/$TOTAL_STEPS] Generating appfs.ext4 (${APPFS_SIZE_MB}MB) and extracting rootfs...${NC}"
rm -f appfs.ext4
dd if=/dev/zero of=appfs.ext4 bs=1M count="$APPFS_SIZE_MB" status=progress
mkfs.ext4 -d appfs appfs.ext4
cp appfs.ext4 "$RELEASE_DIR/"
echo -e "${GREEN}  Created and copied appfs.ext4 to $RELEASE_DIR/${NC}"

# Extract rootfs from CrossControl bundle
rm -rf cclinux-rauc-bundles/latest
chmod 0755 "$BUNDLE_PATH"

$RAUC_BIN extract "$BUNDLE_PATH" \
    --conf="$RAUC_CONF" \
    --keyring="$DEMO_CA_CERT" \
    "$PWD/cclinux-rauc-bundles/latest"

EXTRACTED_MANIFEST="cclinux-rauc-bundles/latest/manifest.raucm"
if [ ! -f "$EXTRACTED_MANIFEST" ]; then
    echo -e "${RED}Error: No manifest.raucm found in extracted bundle${NC}"
    exit 1
fi

# Read rootfs filename and compatible string from the extracted bundle
BUNDLE_ROOTFS=$(awk '/^\[image\.rootfs\]/,/^filename=/' "$EXTRACTED_MANIFEST" | grep '^filename=' | cut -d= -f2)
BUNDLE_COMPATIBLE=$(grep '^compatible=' "$EXTRACTED_MANIFEST" | cut -d= -f2)

if [ -z "$BUNDLE_ROOTFS" ] || [ ! -f "cclinux-rauc-bundles/latest/$BUNDLE_ROOTFS" ]; then
    echo -e "${RED}Error: Rootfs image '$BUNDLE_ROOTFS' not found in extracted bundle${NC}"
    ls -la cclinux-rauc-bundles/latest/ 2>/dev/null
    exit 1
fi

cp "cclinux-rauc-bundles/latest/$BUNDLE_ROOTFS" "$RELEASE_DIR/"
echo -e "${GREEN}  Copied $BUNDLE_ROOTFS to $RELEASE_DIR/${NC}"

# Update release manifest rootfs filename if it differs
CURRENT_ROOTFS=$(awk '/^\[image\.rootfs\]/,/^filename=/' "$RELEASE_DIR/manifest.raucm" | grep '^filename=' | cut -d= -f2)
if [ "$CURRENT_ROOTFS" != "$BUNDLE_ROOTFS" ]; then
    sed -i "s|^filename=$CURRENT_ROOTFS|filename=$BUNDLE_ROOTFS|" "$RELEASE_DIR/manifest.raucm"
    echo -e "${YELLOW}  Updated release manifest rootfs filename: $CURRENT_ROOTFS → $BUNDLE_ROOTFS${NC}"
fi

# Update compatible string in release manifest if it differs
CURRENT_COMPATIBLE=$(grep '^compatible=' "$RELEASE_DIR/manifest.raucm" | cut -d= -f2)
if [ "$CURRENT_COMPATIBLE" != "$BUNDLE_COMPATIBLE" ]; then
    sed -i "s|^compatible=$CURRENT_COMPATIBLE|compatible=$BUNDLE_COMPATIBLE|" "$RELEASE_DIR/manifest.raucm"
    echo -e "${YELLOW}  Updated release manifest compatible: $CURRENT_COMPATIBLE → $BUNDLE_COMPATIBLE${NC}"
fi

# Update compatible string in initialization manifest if it differs
if [ "$SKIP_INIT" = false ] && [ -f "$INIT_DIR/manifest.raucm" ]; then
    INIT_COMPATIBLE=$(grep '^compatible=' "$INIT_DIR/manifest.raucm" | cut -d= -f2)
    if [ "$INIT_COMPATIBLE" != "$BUNDLE_COMPATIBLE" ]; then
        sed -i "s|^compatible=$INIT_COMPATIBLE|compatible=$BUNDLE_COMPATIBLE|" "$INIT_DIR/manifest.raucm"
        echo -e "${YELLOW}  Updated initialization manifest compatible: $INIT_COMPATIBLE → $BUNDLE_COMPATIBLE${NC}"
    fi
fi
STEP=$((STEP + 1))
echo ""

# --- Step 4: Build initialization bundle (signed with demo keys) ---
if [ "$SKIP_INIT" = false ]; then
    echo -e "${BLUE}[Step $STEP/$TOTAL_STEPS] Building initialization bundle...${NC}"

    if [ ! -d "openssl-ca/root/hash" ]; then
        echo -e "${RED}Error: openssl-ca/root/hash/ not found. Run with --generate-ca first.${NC}"
        exit 1
    fi
    if [ ! -f "openssl-login/ccpilot-login-key.pub" ]; then
        echo -e "${RED}Error: openssl-login/ccpilot-login-key.pub not found. Run with --generate-login-key first.${NC}"
        exit 1
    fi

    # Package root CA certs for the initialization bundle
    tar -cf "$PWD/$INIT_DIR/certs.tar" -C openssl-ca/root/hash .
    cp "$PWD/openssl-login/ccpilot-login-key.pub" "$PWD/$INIT_DIR/authorized_keys"

    rm -f "$INIT_BUNDLE"
    $RAUC_BIN bundle \
        --conf="$RAUC_CONF" \
        --keyring="$DEMO_CA_CERT" \
        --key="$DEMO_KEY" \
        --cert="$DEMO_CERT" \
        "$INIT_DIR" \
        "$INIT_BUNDLE"

    echo -e "${GREEN}  Created $INIT_BUNDLE${NC}"
    STEP=$((STEP + 1))
    echo ""
fi

# --- Step 5: Build full release bundle (signed with custom keys) ---
echo -e "${BLUE}[Step $STEP/$TOTAL_STEPS] Building full release bundle with custom keys...${NC}"

ROOT_CA_CERT="$PWD/openssl-ca/root-ca.pem"
DEV_SIGN_KEY="$PWD/openssl-ca/dev/private/developer-1.pem"
DEV_SIGN_CERT="$PWD/openssl-ca/dev/developer-1.cert.pem"
DEV_INTERMEDIATE="$PWD/openssl-ca/dev/ca.cert.pem"

for f in "$ROOT_CA_CERT" "$DEV_SIGN_KEY" "$DEV_SIGN_CERT" "$DEV_INTERMEDIATE"; do
    if [ ! -f "$f" ]; then
        echo -e "${RED}Error: Required key/cert not found: $f${NC}"
        echo "Make sure generate-ca.sh has been run successfully."
        exit 1
    fi
done

rm -f "$INSTALL_BUNDLE"

$RAUC_BIN bundle \
    --conf="$RAUC_CONF" \
    --keyring="$ROOT_CA_CERT" \
    --key="$DEV_SIGN_KEY" \
    --cert="$DEV_SIGN_CERT" \
    --intermediate="$DEV_INTERMEDIATE" \
    "$RELEASE_DIR" \
    "$INSTALL_BUNDLE"

echo ""
echo -e "${GREEN}=== Build complete ===${NC}"
if [ "$SKIP_INIT" = false ]; then
    echo -e "  1. Initialization bundle: ${GREEN}$INIT_BUNDLE${NC}"
    echo -e "  2. Install package:       ${GREEN}$INSTALL_BUNDLE${NC}"
    echo ""
    echo "Deployment order:"
    echo "  1. Install $INIT_BUNDLE via USB → reboot (replaces demo certs)"
    echo "  2. Install $INSTALL_BUNDLE via USB → auto-reboot (full OS + app update)"
else
    echo -e "  Install package: ${GREEN}$INSTALL_BUNDLE${NC}"
    echo "  Copy this file to a USB stick and insert it into the display for installation."
fi
