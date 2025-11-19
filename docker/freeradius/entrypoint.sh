#!/bin/bash
set -e

# Function to add clients from RADIUS_CLIENTS env var
# Format: ipaddr1:secret1,ipaddr2:secret2
add_clients() {
    if [ -n "$RADIUS_CLIENTS" ]; then
        IFS=',' read -ra CLIENTS <<< "$RADIUS_CLIENTS"
        for client in "${CLIENTS[@]}"; do
            IFS=':' read -r ip secret <<< "$client"
            cat >> /usr/local/freeradius/etc/raddb/clients.conf << EOF
client $ip {
	ipaddr = $ip
	secret = $secret
}
EOF
        done
    fi
}

# Function to add users from RADIUS_USERS env var
# Format: username1:password1,username2:password2
add_users() {
    if [ -n "$RADIUS_USERS" ]; then
        IFS=',' read -ra USERS <<< "$RADIUS_USERS"
        for user in "${USERS[@]}"; do
            IFS=':' read -r username password <<< "$user"
            echo "$username Cleartext-Password := \"$password\"" >> /usr/local/freeradius/etc/raddb/users
        done
    fi
}

# Apply configurations
add_clients
add_users

# Start FreeRADIUS server
exec /usr/local/freeradius/sbin/radiusd -f
