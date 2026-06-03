#!/bin/bash
set -e
echo "=== OP-TEE Encrypted Bundle Test ==="
echo "Handler running on device at: $(date)"
echo "RAUC bundle decrypted successfully via OP-TEE PKCS#11!"
echo "Device serial: $(cat /proc/device-tree/serial-number | tr -d '\0')"
echo "=== Test PASSED ==="
exit 0
