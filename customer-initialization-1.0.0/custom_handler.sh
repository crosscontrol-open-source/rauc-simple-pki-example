#!/bin/bash

# This script will be executed as a custom RAUC handler. 
# It can do modifications to /etc or /data to configure for a first time setup of the system
# For example:
#   - Replace CC demo certs with customer generated certs
#   - Remove default SSH login and use SSH keybased login instead or disable it completely
#   - Configure RAUC config file to use encryption
#   - Configure firewall
#   - Configure static IP address
#   - Copy setting files to /data or /etc
#   - Add splash screen
#   - Configure network options for security
#
#   See the CClinux Security Manual for more details
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

#echo "Removing ccs user"
#userdel -r ccs

#echo "Disabling SSH"
#systemctl disable sshd.socket

#echo "Disabling systemd-resolved"
#systemctl disable systemd-resolved

#echo "Disable containerd"
#systemctl disable containerd

#echo "Restricting core dump access"
#if ! grep -q "hard    core" /etc/security/limits.conf ; then
#	echo "*	hard	core	0" >> /etc/security/limits.conf
#	echo "*	soft    core	0" >> /etc/security/limits.conf
#fi

# if [ ! -f /etc/sysctl.d/9999-disable-core-dump.conf]; then
#	echo "fs.suid_dumpable = 0" > /etc/sysctl.d/9999-disable-core-dump.conf
#fi

#echo "Disabling USB input devices"
#if [ ! -f /etc/udev/rules.d/95-disable-usb-input-devices.rules ]; then
#       echo "ACTION==\"add\", SUBSYSTEM==\"input\", SUBSYSTEMS==\"usb\", ATTRS{authorized}==\"1\", \
#       ENV{PARID}=\"\$id\", RUN+=\"/bin/sh -c 'echo 0 >/sys/bus/usb/devices/\$env{PARID}/authorized'\"" \ 
#       > /etc/udev/rules.d/95-disable-usb-input-devices.rules
#fi

#echo "block incoming network traffic in general/remove local net exception"
#mv /etc/iptables/iptables.rules /etc/iptables/iptables.rules.bak
#cat /etc/iptables/iptables.rules.bak | grep -v '10.0.0.0/8\|172.16.0.0/12\|192.168.0.0/16' > /etc/iptables/iptables.rules

#echo "Check ipv4 reverse path validation"
#if [ -e /etc/sysctl.d/9000-ipv4-reverse-path-validation.conf ]; then
#        echo "Reverse path validation already enabled"
#else
#        echo "net.ipv4.conf.all.rp_filter = 2" > /etc/sysctl.d/9000-ipv4-reverse-path-validation.conf
#        echo "net.ipv4.conf.default.rp_filter = 2" >> /etc/sysctl.d/9000-ipv4-reverse-path-validation.conf
#        echo "net.ipv4.conf.default.accept_source_route = 2"  >> /etc/sysctl.d/9000-ipv4-reverse-path-validation.conf
#        echo "net.ipv4.conf.all.accept_source_route = 2" >> /etc/sysctl.d/9000-ipv4-reverse-path-validation.conf
#fi

sync

echo "Update complete."
echo "<< handler [DONE]"

exit 0


