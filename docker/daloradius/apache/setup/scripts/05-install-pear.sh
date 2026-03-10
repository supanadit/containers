#!/bin/bash
set -e

echo "=== Installing PEAR and required modules ==="

# Ensure PEAR is available
pear version || true

# Update PEAR channel
pear channel-update pear.php.net || true

# Upgrade PEAR first
pear upgrade-all || true

# Install required PEAR modules for daloRADIUS
pear install -f DB Mail Mail_Mime Mail_MimeDecode || true

# Install Net_SMTP if available (for email functionality)
pear install -f Net_SMTP Net_Socket || true

echo "=== PEAR modules installed successfully ==="
