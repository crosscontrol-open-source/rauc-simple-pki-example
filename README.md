
# RAUC Package Generation Tools for CrossControl Displays

This repository contains a collection of helper scripts and examples designed to streamline the creation of RAUC update bundles for CrossControl CCpilot displays. The scripts helps to automate the steps required to package application filesystem (appfs) and Linux OS (rootfs) into signed, deployable update artifacts. This guide covers two workflows depending on your deployment stage.

## Prerequisites 

The examples require RAUC to be installed on the development computer. CCLinux OS includes an up-to-date version of the tool, and to ensure full compatibility, it is recommended to use the same version during development. Each CCLinux SDK provides an x86_64-compiled RAUC binary for creating and managing RAUC bundles. The SDK can be downloaded from the CrossControl website.
After installing the SDK, update the SDK installation path in conf.sh.

## Example 1 - Build package using CrossControl demo keys for a CCPilot display

### Quick start (automated)

1. Place a file or application in the **appfs** folder.
2. Download a released OS bundle from CrossControl and place it in **cclinux-rauc-bundles/**.
3. Run `./build-all-demo.sh`. This generates the appfs image, extracts the rootfs, copies everything into place, and builds the signed bundle in one step.
4. Install the created RAUC bundle by copying it to a USB stick and inserting it into the display.

Options: `./build-all-demo.sh --version 2.0.0 --appfs-size 800 --bundle path/to/file.raucb`

### Manual step-by-step

1. Place a file or application in **appfs** folder. The content of this folder will be installed to **/appfs** in the display by the RAUC package.
2. Run the **generate-appfs-ext4.sh** script. It will use the content of the newly created appfs folder and add it to an ext4 image. Copy the now created **appfs.ext4** to **release-full-1.0.0 folder**.
3. From CrossControl web site, download a released OS bundle, for example **CCpilot-v700-4.2.0.0-rootfs-update-bundle.raucb**. Place this file in folder **cclinux-rauc-bundles**. 
4. Run the **extract-bundle.sh** script to extract the rootfs.ext4 image. Each RAUC bundle should contain a combination of the rootfs image for the specific target device together with the application partition image to be able to deploy a valid combination of Linux OS and application in one atomic update. After extraction, copy the file **latest/ccpilot-v700-release-v700.ext4** to **release-full-1.0.0** folder.
5. Check the **manifest.raucm** in the **release-full-1.0.0** folder. The manifest should be changed to match the names for the selected target device. In this example, V700 is the default. 
6. Run **build-full-release-with-demo-keys.sh** to create an installation package that uses the same demo keys included in CCLinux 4.2 standard image. This will create a bundle compatible with the publicly shared CrossControl demo keys and should only be used for testing purposes.
7. Install the the created RAUC bundle by copy it to a USB stick and insert to the display for installation.


## Example 2 - Deployment work flow with customer specific keys for a CCPilot display

### Quick start (automated)

1. Place a file or application in the **appfs** folder.
2. Download a released OS bundle from CrossControl and place it in **cclinux-rauc-bundles/**.
3. Run `./build-all.sh` — this generates CA keys, login keys, appfs image, extracts rootfs, and builds both the initialization and install bundles.
4. Install **initialization-1.0.0.raucb** via USB →  reboot (lock the device with customer generated keys).
5. Install **install-package-1.0.0.raucb** via USB →  reboot (full OS + app update).

Options: `./build-all.sh --version 2.0.0 --appfs-size 800 --generate-ca --generate-login-key`

### Manual step-by-step

1. Run the **generate-ca.sh** script to get a set of private keys and certificates for signing. It will create a stucture with keys and certificates commonly used for CA setups, described in detail below. The developer certificate is used in this example. 
2. Run the **generate-login-key.sh** to get a key-pair to be able to ssh to the display in a secure way instead of default password.
3. Place a file or application in **appfs** folder. The content of this folder will be installed to **/appfs** in the display by the RAUC package.
4. Run the **generate-appfs-ext4.sh** script. It will use the content of the newly created appfs folder and add it to an ext4 image. Copy the now created appfs.ext4 to release-full-1.0.0 folder.
5. Run build-initialization-bundle.sh script to create a RAUC package that will replace the demo certificate in the standard CCPilot 4.x image to a customer specfic version. Check custom-handler.sh if additional configuration is needed (for example static IP address)
6. From CrossControl web site, download a released OS bundle, for example **CCpilot-v700-4.2.0.0-rootfs-update-bundle.raucb**. Place this file in folder **cclinux-rauc-bundles**. 
7. Run the **extract-bundle.sh** script to extract the rootfs.ext4 image. Each RAUC bundle should contain a combination of the rootfs image for the specific target device together with the application partition image to be able to deploy a valid combination of Linux OS and application in one atomic update. After extraction, copy the file **latest/ccpilot-v700-release-v700.ext4** to release-full-1.0.0 folder. 
8. Check the **manifest.raucm** in the release-full-1.0.0 folder. The manifest should be changed to match the names for the selected target device. In this example, V700 is the default. 
9. Run **build-full-release.sh** to create an installation package that uses the custom sign key.
10. Install the initialization RAUC bundle by copy it to a USB stick and insert to the display. This will replace demo certificate and configure the display to use encryption. Reboot!
11. Install the newly created **install-package-1.0.0.raucb** bundle by copy it to a USB stick and insert it to the display. The display will reboot after installation.


## Example 3 - Encrypted bundles using OP-TEE PKCS#11 on a CCPilot V700

This example extends Example 2 by adding RAUC bundle encryption. Bundles are
encrypted on the build host using an RSA public key. Only a device that holds
the matching private key inside its OP-TEE secure storage (backed by the i.MX8
CAAM crypto engine) can decrypt and install the bundle.

The flow has two distinct phases: **key setup** (done once, or once per key
rotation) and **device provisioning** (done once per device).

### Key setup (done once)

1. Run `./generate-ca.sh` to create the PKI used for bundle signing (same as Example 2).
2. Run `./generate-enc-key.sh` to create the RSA encryption key pair.
   - `bundle-enc-key/rauc-enc.key.pem` — private key, stays on the build host.
   - `bundle-enc-key/rauc-enc.cert.pem` — public certificate, committed to the repo and used when encrypting bundles.

### Device provisioning (done once per device)

3. Run `./provision-device-optee.sh [user@host]` to import the private key into the device's OP-TEE PKCS#11 token.
   The script connects over SSH, initialises the PKCS#11 token if needed, imports the key into CAAM-backed secure storage, then deletes the plaintext copy from the device.
   The default target host is set by `DEVICE_HOST` in `conf.sh`.

### Build and install initialization bundle

4. Run `./generate-login-key.sh` to create an SSH key pair for keyless login.
5. Run `./build-initialization-bundle.sh` to create `initialization-1.0.0.raucb`.
   This bundle deploys:
   - The new root CA certificate (replacing the CC demo cert).
   - The updated `system.conf` with the `[encryption]` section pointing to the OP-TEE key.
   - A systemd drop-in (`rauc.service.d/pkcs11-decrypt.conf`) that provides the PKCS#11 PIN to the RAUC service.
6. Install `initialization-1.0.0.raucb` on the device (USB or `rauc install`). Reboot.

### Build and install an encrypted release bundle

7. Prepare `release-full-1.0.0/` as in Example 2 (rootfs + appfs images, correct manifest).
8. Run `./build-full-release-encrypted.sh` to create `install-package-encrypted-1.0.0.raucb`.
   The script runs two steps internally:
   - `rauc bundle --format=crypt` — signs the bundle and AES-encrypts the payload.
   - `rauc encrypt --to bundle-enc-key/rauc-enc.cert.pem` — wraps the AES key with the RSA public key.
9. Install `install-package-encrypted-1.0.0.raucb` on the provisioned device. The RAUC service will use the OP-TEE private key to unwrap the AES key and install the bundle.

> **Note:** `rauc info` on an encrypted bundle requires the same PKCS#11 environment variables that the systemd service has. Run it as:
> ```
> RAUC_PKCS11_MODULE=/usr/lib/libckteec.so.0 RAUC_PKCS11_PIN=1234 rauc info install-package-encrypted-1.0.0.raucb
> ```

### Key strategy note

This demo uses a single key pair shared by all devices. For production deployments consider:

- **Batch keys** — one key pair per manufacturing batch. A compromised batch key only affects that batch.
- **Per-device keys** — maximum isolation. Each device has a unique key pair registered in a device management system.

To encrypt for multiple recipients, concatenate their certificates before running `build-full-release-encrypted.sh`:

```bash
cat bundle-enc-key/batch-A.cert.pem bundle-enc-key/batch-B.cert.pem > /tmp/recipients.pem
```

Then update `RECIPIENTS_CERT` in `build-full-release-encrypted.sh` to point to `/tmp/recipients.pem`.

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

Each CCpilot display type has a unique string to identify the unit. A CCPilot V700 has for example the identifier: "compatible=CrossControl V700". A RAUC bundle has match this string, and each manifest file contains a mandatory **compatible** property. Make sure to set this to your device type. 

Note about appfs folder: RAUC requires the appfs image to be at least 4k in size. If only adding a small file to the appfs folder, the script will fail.

## Demo keys used to sign first package used to replace standard CC keys
cc-demo-keys 
cc-demo-keys/old-keys (used in CCLinux 4.0 and 4.1)

## Helper scripts for extracting or re-signing CrossControl RAUC bundles
cclinux-rauc-bundles

## Release folders
customer-initialization-1.0.0
release-full-1.0.0

## Build Scripts
build-all-demo.sh — automated demo keys workflow
build-all.sh — automated custom keys workflow 
build-initialization-bundle.sh
build-full-release.sh
build-full-release-with-demo-keys.sh
build-full-release-encrypted.sh — encrypted bundle workflow (Example 3)

## Helper scripts
generate-ca.sh
generate-login-key.sh
generate-enc-key.sh — one-time encryption key pair generation (Example 3)
generate-appfs-ext4.sh
provision-device-optee.sh — per-device OP-TEE provisioning (Example 3)
cclinux-os-bundles/extract-bundle.sh
cclinux-os-bundles/resign-bundle.sh

## Output folders generated from helper scripts
openssl-login
openssl-ca
bundle-enc-key — encryption key pair (rauc-enc.key.pem gitignored, rauc-enc.cert.pem committed)

## Output bundles produced by this example
initialization-1.0.0.raubc
install-package-1.0.0.raucb
install-package-encrypted-1.0.0.raucb — encrypted bundle (Example 3)
