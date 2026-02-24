#!/bin/bash

# Simulate the apply_postgres_setting function logic
apply_postgres_setting() {
    local setting="$1"
    local value="$2"
    
    if [ -z "$value" ]; then
        return 0
    fi
    
    # Determine formatting based on value type
    local formatted_value
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        formatted_value="$value"
    elif [[ "$value" =~ ^(on|off|true|false|replica|minimal|archive|hot_standby)$ ]]; then
        formatted_value="$value"
    elif [[ "$value" =~ ^[0-9]+(kB|MB|GB|TB|ms|s|min|h|d)$ ]]; then
        formatted_value="$value"
    else
        printf -v formatted_value "'%s'" "$value"
    fi
    
    echo "${setting} = ${formatted_value}"
}

echo "Testing synchronous_standby_names with correct quoting:"
apply_postgres_setting "synchronous_standby_names" "*"
echo ""
echo "Testing synchronous_standby_names with incorrect quoting:"
apply_postgres_setting "synchronous_standby_names" "'*'"
