#!/bin/bash

# This script will be executed as a custom RAUC handler. 
# It can do modifications to /etc or /data to configure for a first time setup of the system
# For example:
#   - Replace CC demo certs with customer generated certs
#   - Remove default SSH login and use SSH keybased login instead
#   - Configure RAUC config file to use encryption
#   - Configure firewall
#   - Configure static IP address
#   - Copy setting files to /data or /etc
#   - Add splash screen
# Examples below:

set -e

echo "<< debug $*"
echo "<< handler [STARTED]"

function exit_if_empty {
	if [ -z "$1" ]; then exit 1; fi
}

# Sanity check
for i in $(env | grep "^RAUC_"); do
	echo $i
	exit_if_empty $i
done

# Remove CC Demo cert 
rm /data/rauc/certs/*
# Copy new generated certs in hash form to certs folder
tar -xf $RAUC_BUNDLE_MOUNT_POINT/certs.tar -C /data/rauc/certs

# Configure keyless login  instead of default password
mkdir -p /data/home/ccs/.ssh
cp $RAUC_BUNDLE_MOUNT_POINT/authorized_keys /data/home/ccs/.ssh
cp $RAUC_BUNDLE_MOUNT_POINT/sshd_config /etc/ssh/

# Configure firewall, replace with a new iptables.rules 
#cp $RAUC_BUNDLE_MOUNT_POINT/iptables.rules /etc/iptables/

# Configure network with static IP
#nmcli connection modify "Wired connection 1" ipv4.addresses "192.168.1.100/24"
#nmcli connection modify 'Wired connection 1' ipv4.gateway 192.168.1.1
#nmcli connection modify 'Wired connection 1' ipv4.dns "8.8.8.8 8.8.4.4"
#nmcli connection modify 'Wired connection 1' ipv4.method manual

# Disable getty service to remove login screen after bootup for security.
#systemctl disable getty@.service

# Splash screen are located in /etc so replace psplash and/or psplash-write
#cp $RAUC_BUNDLE_MOUNT_POINT/psplash /etc
#cp $RAUC_BUNDLE_MOUNT_POINT/psplash-write /etc

sync

echo "Update complete."
echo "<< handler [DONE]"

exit 0


