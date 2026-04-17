#!/bin/bash
#
# Automated workflow for building a RAUC bundle signed with CrossControl demo keys.
# Combines: generate-appfs-ext4.sh + extract-bundle.sh + copy steps + build-full-release-with-demo-keys.sh
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

Build a RAUC installation bundle using CrossControl demo keys.
Automates the full workflow: generate appfs, extract rootfs, and build the signed bundle.

Options:
  --version VERSION    Bundle version (default: $VERSION)
  --appfs-size SIZE    Appfs image size in MB (default: $APPFS_SIZE_MB)
  --bundle PATH        Path to CrossControl .raucb bundle file
                       (auto-detected from cclinux-rauc-bundles/ if only one exists)
  -h, --help           Show this help message

Prerequisites:
  - CrossControl SDK installed (path configured in conf.sh)
  - Application content placed in appfs/ folder (minimum 4KB total)
  - CrossControl rootfs bundle (.raucb) placed in cclinux-rauc-bundles/
  - manifest.raucm configured for your target device in release-full-<version>/
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --version) VERSION="$2"; shift 2 ;;
        --appfs-size) APPFS_SIZE_MB="$2"; shift 2 ;;
        --bundle) BUNDLE_PATH="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; usage ;;
    esac
done

RELEASE_DIR="release-full-$VERSION"
BUNDLE_NAME="install-package-$VERSION.raucb"

# --- Source SDK configuration ---
source conf.sh
RAUC_BIN="$SDK_INSTALL_PATH/sysroots/x86_64-cclinuxsdk-linux/usr/bin/rauc"
RAUC_CONF="$PWD/rauc-host.conf"
DEMO_CA_CERT="$PWD/cc-demo-keys/ca.cert.pem"
DEMO_KEY="$PWD/cc-demo-keys/development-1.key.pem"
DEMO_CERT="$PWD/cc-demo-keys/development-1.cert.pem"

echo -e "${BLUE}=== RAUC Bundle Builder (Demo Keys) ===${NC}"
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

# --- Step 1: Generate appfs.ext4 ---
echo -e "${BLUE}[Step 1/3] Generating appfs.ext4 (${APPFS_SIZE_MB}MB)...${NC}"
rm -f appfs.ext4
dd if=/dev/zero of=appfs.ext4 bs=1M count="$APPFS_SIZE_MB" status=progress
mkfs.ext4 -d appfs appfs.ext4
cp appfs.ext4 "$RELEASE_DIR/"
echo -e "${GREEN}  Created and copied appfs.ext4 to $RELEASE_DIR/${NC}"
echo ""

# --- Step 2: Extract rootfs from CrossControl bundle ---
echo -e "${BLUE}[Step 2/3] Extracting rootfs from $(basename "$BUNDLE_PATH")...${NC}"
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

# Update manifest rootfs filename if it differs
CURRENT_ROOTFS=$(awk '/^\[image\.rootfs\]/,/^filename=/' "$RELEASE_DIR/manifest.raucm" | grep '^filename=' | cut -d= -f2)
if [ "$CURRENT_ROOTFS" != "$BUNDLE_ROOTFS" ]; then
    sed -i "s|^filename=$CURRENT_ROOTFS|filename=$BUNDLE_ROOTFS|" "$RELEASE_DIR/manifest.raucm"
    echo -e "${YELLOW}  Updated manifest rootfs filename: $CURRENT_ROOTFS → $BUNDLE_ROOTFS${NC}"
fi

# Update manifest compatible string if it differs
CURRENT_COMPATIBLE=$(grep '^compatible=' "$RELEASE_DIR/manifest.raucm" | cut -d= -f2)
if [ "$CURRENT_COMPATIBLE" != "$BUNDLE_COMPATIBLE" ]; then
    sed -i "s|^compatible=$CURRENT_COMPATIBLE|compatible=$BUNDLE_COMPATIBLE|" "$RELEASE_DIR/manifest.raucm"
    echo -e "${YELLOW}  Updated manifest compatible: $CURRENT_COMPATIBLE → $BUNDLE_COMPATIBLE${NC}"
fi
echo ""

# --- Step 3: Build the signed bundle ---
echo -e "${BLUE}[Step 3/3] Building RAUC bundle with demo keys...${NC}"
rm -f "$BUNDLE_NAME"

$RAUC_BIN bundle \
    --conf="$RAUC_CONF" \
    --keyring="$DEMO_CA_CERT" \
    --key="$DEMO_KEY" \
    --cert="$DEMO_CERT" \
    "$RELEASE_DIR" \
    "$BUNDLE_NAME"

echo ""
echo -e "${GREEN}=== Build complete ===${NC}"
echo -e "  Bundle: ${GREEN}$BUNDLE_NAME${NC}"
echo "  Copy this file to a USB stick and insert it into the display for installation."
