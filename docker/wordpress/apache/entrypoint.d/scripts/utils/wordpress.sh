#!/bin/bash
# wordpress.sh - WordPress-specific utilities

# Generate WordPress salts
generate_wordpress_salts() {
    log_info "Generating WordPress salts"
    curl -s https://api.wordpress.org/secret-key/1.1/salt/
}

# Update wp-config.php with database settings
update_wp_config_database() {
    local config_file="$1"

    log_info "Updating database settings in wp-config.php"

    sed -i "s/database_name_here/${WORDPRESS_DB_NAME}/" "$config_file"
    sed -i "s/username_here/${WORDPRESS_DB_USER}/" "$config_file"
    sed -i "s/password_here/${WORDPRESS_DB_PASSWORD}/" "$config_file"
    sed -i "s/localhost/${WORDPRESS_DB_HOST}/" "$config_file"
}

# Add or update define statement in wp-config.php
update_wp_config_define() {
    local config_file="$1"
    local var_name="$2"
    local var_value="$3"

    log_debug "Updating define statement for $var_name"

    # Detect multi-line array/object
    if [[ "$var_value" =~ ^\[ ]] || [[ "$var_value" =~ ^array\( ]]; then
        # Remove trailing newline before ] or )
        local cleaned_var_value
        cleaned_var_value="$(echo "$var_value" | sed ':a;N;$!ba;s/\n\([])]\)$/\1/')"
        local define_stmt="define('$var_name', $cleaned_var_value);"
    # Detect boolean or number
    elif [[ "$var_value" =~ ^(true|false|[0-9]+)$ ]]; then
        local define_stmt="define('$var_name', $var_value);"
    else
        local define_stmt="define('$var_name', '$var_value');"
    fi

    if grep -q "define('$var_name'" "$config_file"; then
        awk -v name="$var_name" -v stmt="$define_stmt" '
            BEGIN {replaced=0}
            {
                if ($0 ~ "define.\x27" name "\x27") {
                    print stmt
                    replaced=1
                    while (replaced && !($0 ~ /\);/)) getline
                    next
                }
                print
            }
        ' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
    else
        awk -v stmt="$define_stmt" '
            NR==1 {print; print stmt; next}
            {print}
        ' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
    fi
}

# Update table prefix in wp-config.php
update_table_prefix() {
    local config_file="$1"
    local prefix="$2"

    log_info "Updating table prefix to '$prefix'"

    if ! grep -q "\$table_prefix = '$prefix';" "$config_file"; then
        awk -v prefix="$prefix" '
        /table_prefix =/ {
            sub(/table_prefix = .*/, "table_prefix = '\''" prefix "'\'';");
            print;
            next
        }
        {print}
        ' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
    fi
}

# Add HTTPS configuration to wp-config.php
add_https_config() {
    local config_file="$1"

    log_info "Adding HTTPS configuration to wp-config.php"

    if ! grep -q "\$_SERVER\['HTTPS'\] = 'on';" "$config_file"; then
        awk "
        NR==1 {print; next}
        NR==2 {
            print \"if ( isset( \$_SERVER['HTTP_X_FORWARDED_PROTO'] ) && 'https' == \$_SERVER['HTTP_X_FORWARDED_PROTO'] ) {\";
            print \"    \$_SERVER['HTTPS'] = 'on';\";
            print \"}\";
            print;
            next
        }
        {print}
        " "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
    fi
}

# Remove HTTPS configuration from wp-config.php
remove_https_config() {
    local config_file="$1"

    log_info "Removing HTTPS configuration from wp-config.php"

    if grep -q "isset( \$_SERVER\['HTTP_X_FORWARDED_PROTO'\] )" "$config_file"; then
        sed -i "/if ( isset( \$_SERVER\['HTTP_X_FORWARDED_PROTO'\] ) && 'https' == \$_SERVER\['HTTP_X_FORWARDED_PROTO'\] ) {/,/}/d" "$config_file"
    fi
}

# Add loopback fix to wp-config.php
add_loopback_fix() {
    local config_file="$1"

    log_info "Adding loopback request fix to wp-config.php"

    if ! grep -q "add_filter( 'pre_http_request'" "$config_file"; then
        cat >> "$config_file" << 'EOF'

// Fix loopback requests for Docker containers
add_filter( 'pre_http_request', function( $preempt, $parsed_args, $url ) {
    if ( strpos( $url, 'localhost' ) !== false ) {
        $parsed = parse_url( $url );
        $new_url = $parsed['scheme'] . '://127.0.0.1' . ( isset( $parsed['path'] ) ? $parsed['path'] : '/' ) . ( isset( $parsed['query'] ) ? '?' . $parsed['query'] : '' );
        return wp_remote_request( $new_url, $parsed_args );
    }
    return $preempt;
}, 10, 3 );

EOF
    fi
}