<?php
// Proxy-aware HTTPS shim: when the request arrives via a reverse proxy that
// terminates TLS, X-Forwarded-Proto=https signals WordPress to treat the
// request as HTTPS. Enabled with IS_HTTPS=true.
if ( isset( $_SERVER['HTTP_X_FORWARDED_PROTO'] ) && 'https' == $_SERVER['HTTP_X_FORWARDED_PROTO'] ) {
    $_SERVER['HTTPS'] = 'on';
}
