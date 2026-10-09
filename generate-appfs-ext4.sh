#!/bin/sh

set -e

trap 'rm -f appfs.ext4.tmp' EXIT
rm -f appfs.ext4 appfs.ext4.tmp

# Check if the directory "appfs" exists
if [ ! -d "appfs" ]; then
    echo "Error: Folder 'appfs' does not exist! "
    echo "Create this folder and prepare it with the content intended for appfs."
    echo "Also adjust size in this script to match the appfs partition size on target device."
    echo "This script will create an ext4 image to be used in full-release package"
    exit 1
fi

dd if=/dev/zero of=appfs.ext4.tmp bs=1M count=0 seek=800
# Create an ext4 file system in the image
if ! mkfs.ext4 -F -d appfs appfs.ext4.tmp; then
    echo "Error: Failed to create appfs filesystem image; its contents may exceed the image capacity; see the mkfs.ext4 output for details." >&2
    exit 1
fi
mv appfs.ext4.tmp appfs.ext4

