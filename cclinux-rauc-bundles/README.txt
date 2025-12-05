A rootfs.ext4 image is needed to build a RAUC installation package. 
A RAUC bundle typically consists of a tested combination of rootfs + appfs images to ensure compatibility.

Download the correct rootfs image from CrossControl.com web site. 
Use any of the pre-compiled bundles:
   - <device>-system-update-bundle.raucb 
   - <device>-os-update-bundle.raucb 
   - <device>-rootfs-update-bundle.raucb 

Included in this folder is a bash script to extract the content of the bundle into folder "latest".
A helper script to resign a CrossControl demo key signed bundle with your specific key is also available.

   - extract-bundle.sh
   - resign-bundle.sh

Usage:
  ./extract-bundle.sh CCpilot-v700-4.1.0.0-rootfs-update-bundle.raucb
  ./resign-bundle.sh CCpilot-v700-4.1.0.0-rootfs-update-bundle.raucb


The extracted rootfs.ext4 image should be copied to the full-release-folder as it should contain both rootfs + appfs ext4 images
