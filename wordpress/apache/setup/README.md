# Setup Scripts

This directory contains modular shell scripts that build the WordPress + Apache + PHP Docker image. The scripts are designed to be executed in sequence by the main `setup.sh` script.

## Script Overview

### Main Script
- **`setup.sh`** - Main orchestration script that executes all setup scripts in the correct order

### Individual Setup Scripts (executed in order)

1. **`01-install-dependencies.sh`** - Installs system dependencies and build tools
2. **`02-install-apr.sh`** - Downloads, compiles, and installs Apache Portable Runtime (APR) and APR-util
3. **`03-install-apache.sh`** - Downloads, compiles, and installs Apache HTTP Server
4. **`04-install-php.sh`** - Downloads, compiles, and installs PHP with core modules
5. **`05-install-php-extensions.sh`** - Installs additional PHP extensions (EXIF, OPCache, Redis, Memcached)
6. **`06-install-wordpress.sh`** - Downloads and installs WordPress
7. **`07-configure-apache.sh`** - Configures Apache for WordPress and PHP
8. **`08-install-plugins-themes.sh`** - Installs WordPress plugins and themes
9. **`09-cleanup.sh`** - Cleans up build artifacts and temporary files

## Benefits

- **Single Layer**: All build operations are executed in one RUN command, reducing Docker image layers
- **Modular**: Each script handles a specific component, making it easy to modify or debug
- **Readable**: Clear separation of concerns makes the build process easy to understand
- **Maintainable**: Individual scripts can be updated without affecting others
- **Efficient**: Cleanup is performed at the end, minimizing final image size

## Usage

The scripts are automatically executed by the Dockerfile using:

```dockerfile
RUN chmod +x /opt/setup.sh && \
    /opt/setup.sh
```

Each script includes error handling (`set -e`) and will stop the build process if any command fails.

## Environment Variables

The scripts use the following ARG variables from the Dockerfile:
- `WORDPRESS_VERSION`
- `APACHE_VERSION` 
- `PHP_VERSION`
- `APR_VERSION`
- `APR_UTIL_VERSION`

## Script Dependencies

Scripts must be executed in the specified order as later scripts depend on components installed by earlier scripts:
- APR must be installed before Apache
- Apache must be installed before PHP (for mod_php)
- PHP must be installed before PHP extensions
- All base components must be ready before WordPress installation
