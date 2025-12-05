
# RAUC Package Generation Tools for CrossControl Displays

This repository contains a collection of helper scripts and examples designed to streamline the creation of RAUC update bundles for CrossControl CCpilot displays. The scripts helps to automate the steps required to package application filesystem (appfs) and Linux OS (rootfs) into signed, deployable update artifacts. This guide covers two workflows depending on your deployment stage.

## Prerequirements

Each CCLinux SDK contains an x86_64 compiled version of the rauc tool used for creation and manipulation of RAUC bundles. The SDK can be downloaded from CrossControl website. Modify alternative SDK installation path in file conf.sh. 

## Example 1 - Build package using CrossControl demo keys for a CCPilot display

1. Place a file or application in **appfs** folder. The content of this folder will be installed to **/appfs** in the display by the RAUC package.
2. Run the **generate-appfs-ext4.sh** script. It will use the content of the newly created appfs folder and add it to an ext4 image. Copy the now created **appfs.ext4** to **release-1.0.0 folder**.
3. From CrossControl web site, download a released OS bundle, for example **CCpilot-v700-4.2.0.0-rootfs-update-bundle.raucb**. Place this file in folder **cclinux-rauc-bundles**. 
4. Run the **extract-bundle.sh** script to extract the rootfs.ext4 image. Each RAUC bundle should contain a combination of the rootfs image for the specific target device together with the application partition image to be able to deploy a valid combination of Linux OS and application in one atomic update. After extraction, copy the file **latest/ccpilot-v700-release-v700.ext4** to **release-1.0.0** folder.
5. Check the **manifest.raucm** in the **release-1.0.0** folder. The manifest should be changed to match the names for the selected target device. In this example, V700 is the default. 
6. Run **build-full-release-with-demo-keys.sh** to create an installation package that uses the same demo keys included in CCLinux 4.2 standard image. This will create a bundle compatible with the publicly shared CrossControl demo keys and should only be used for testing purposes.
7. Install the the created RAUC bundle by copy it to a USB stick and insert to the display for installation.


## Example 2 - Deployment work flow with customer specific keys for a CCPilot display

1. Run the **generate-ca.sh** script to get a set of private keys and certificates for signing. It will create a stucture with keys and certificates commonly used for CA setups, described in detail below. The developer certificate is used in this example. 
2. Run the **generate-login-key.sh** to get a key-pair to be able to ssh to the display in a secure way instead of default password.
3. Place a file or application in **appfs** folder. The content of this folder will be installed to **/appfs** in the display by the RAUC package.
4. Run the **generate-appfs-ext4.sh** script. It will use the content of the newly created appfs folder and add it to an ext4 image. Copy the now created appfs.ext4 to release-1.0.0 folder.
5. Run build-initialization-bundle.sh script to create a RAUC package that will replace the demo certificate in the standard CCPilot 4.x image to a customer specfic version. Check custom-handler.sh if additional configuration is needed (for example static IP address)
6. From CrossControl web site, download a released OS bundle, for example **CCpilot-v700-4.2.0.0-rootfs-update-bundle.raucb**. Place this file in folder **cclinux-rauc-bundles**. 
7. Run the **extract-bundle.sh** script to extract the rootfs.ext4 image. Each RAUC bundle should contain a combination of the rootfs image for the specific target device together with the application partition image to be able to deploy a valid combination of Linux OS and application in one atomic update. After extraction, copy the file **latest/ccpilot-v700-release-v700.ext4** to release-1.0.0 folder. 
7. Check the **manifest.raucm** in the release-1.0.0 folder. The manifest should be changed to match the names for the selected target device. In this example, V700 is the default. 
8. Run **build-full-release.sh** to create an installation package that uses the custom sign key.
9. Install the initialization RAUC bundle by copy it to a USB stick and insert to the display. This will replace demo certificate and configure the display to use encryption. Reboot!
10. Install the newly created **install-package-1.0.0.raucb** bundle by copy it to a USB stick and insert it to the display. The display will reboot after installation.


## Detailed description of example 2.

The helper scripts should be executed first. First run the **generate-ca.sh** script to create a simple CA setup. The output folder **openssl-ca** folder will after this contain a PKI setup with a Root CA, several developer certificates and Release CA. The build scripts can be modified to use
different certificates depending on if it is a release build or a developer build (currenly set to development builds). A CRL (Certificate Revocation List)
is also generated, so it is possible to revoke certificates if a key has been leaked (CRL is not enabled by default). 

The example structure will be:

```
Root CA (keep secure offline)
  ├── Development Intermediate CA
  │     ├── Developer-1 Signing Cert
  │     └── Developer-2 Signing Cert
  └── Release Intermediate CA
        └── Production Signing Cert
``` 

A bundle signed with developer certificate can be re-signed: https://rauc.readthedocs.io/en/v1.6/advanced.html?highlight=crl#resigning-bundles. An example resign script is located in the cclinux-rauc-bundles folder.

The **generate-login-key.sh** script will generate an openssl key-pair that can be used for SSH keyless login to the unit, and replaces the default password approach. It is then possible to log in to the display using "ssh -i device-login-key ccs@192.168.1.100"

**build-initialization-bundle.sh** script will generate a bundle, signed with CrossControl demo keys, that can be installed in the standard CCL4 image. 
This package will replace demo certificates and add keyless SSH login public key to the image. It can also setup for example network and firewall rules if enabled in the custom handler script included. After this package is installed, the display is only accessible with the new keys generated in this example. 

**build-full-release.sh** will create a combined big bundle with selected OS version + content from the **appfs** folder. This is signed with the new keys generated in this example. The package can only be installed after **initialization-1.0.0.raubc** bundle has been installed.
This package contains all files for a tested system combination, rootfs + Appfs

**build-full-release-with-demo-keys.sh** script will do the same as the above script, but use the demo keys instead of custom keys and encryption. Useful for testing RAUC and install software without thinking of security, like demos.

**generate-appfs-ext4.sh** will package the content of **appfs** folder in this project and create an appfs.ext4 image based on the content. 
This should be then copied into the "release-full-<version>" folder to include the latest changes. 

Each CCpilot display type has a unique string to identify the unit. A CCPilot V700 has for example the indntifier: "compatible=CrossControl V700". A RAUC bundle has match this string, and each manifest file contains a mandatory **compatible** property. Make sure to set this to your device type. 

Note about appfs folder: RAUC requires the appfs image to be at least 4k in size. If only adding a small file to the appfs folder, the script will fail.

## Demo keys used to sign first package used to replace standard CC keys
cc-demo-keys
cc-demo-keys/old-keys (used in CCLinux 4.0 and 4.1)        

### Folder where the CrossControl rootfs bundle is stored, also extract script in here
### Used when building full OS+Apps bundle 
cclinux-rauc-bundles  

## Release folders
### Create one for each new release

customer-initialization-1.0.0
release-full-1.0.0  

## Build Scripts

build-initialization-bundle.sh  
build-full-release.sh           
build-full-release-with-demo-keys.sh

## Helper scripts

generate-ca.sh      
generate-login-key.sh  
generate-appfs-ext4.sh
cclinux-os-bundles/extract-bundle.sh
cclinux-os-bundles/resign-bundle.sh

## Output folders generated from helper scripts

openssl-login       
openssl-ca                

## Output bundles produced by this example

initialization-1.0.0.raubc
install-package-1.0.0.raucb
