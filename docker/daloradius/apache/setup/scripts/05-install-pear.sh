#!/bin/bash
set -e

echo "=== Installing PEAR and required modules ==="

# Ensure PEAR is available
pear version || true

# Update PEAR channel
pear channel-update pear.php.net || true

# Install required PEAR modules for daloRADIUS
pear install DB
pear install Mail
pear install Mail_Mime
pear install Mail_MimeDecode

# Install Net_SMTP if available (for email functionality)
pear install Net_SMTP || true
pear install Net_Socket || true

echo "=== PEAR modules installed successfully ==="
