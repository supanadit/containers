<?php
// Fix loopback HTTP requests inside a container: WordPress health checks and
// cron hit "localhost", which resolves to the container itself rather than the
// web server. Rewrite those requests to 127.0.0.1 so they succeed.
add_filter( 'pre_http_request', function( $preempt, $parsed_args, $url ) {
    if ( strpos( $url, 'localhost' ) !== false ) {
        $parsed = parse_url( $url );
        $new_url = $parsed['scheme'] . '://127.0.0.1' . ( isset( $parsed['path'] ) ? $parsed['path'] : '/' ) . ( isset( $parsed['query'] ) ? '?' . $parsed['query'] : '' );
        return wp_remote_request( $new_url, $parsed_args );
    }
    return $preempt;
}, 10, 3 );
