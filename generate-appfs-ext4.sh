#!/bin/sh

# Check if the directory "appfs" exists
if [ ! -d "appfs" ]; then
    echo "Error: Folder 'appfs' does not exist! "
    echo "Create this folder and prepare it with the content intended for appfs."
    echo "Also adjust size in this script to match the appfs partition size on target device."
    echo "This script will create an ext4 image to be used in full-release package"
    exit 1
fi

# Remove old appfs.ext4 image if existing
rm appfs.ext4

# Create an empty appfs image file with the size needed for the package. This size must be smaller or equal to the appfs partition size of this device.
dd if=/dev/zero of=appfs.ext4 bs=100M count=8
# Create an ext4 file system in the image
mkfs.ext4 -d appfs appfs.ext4

