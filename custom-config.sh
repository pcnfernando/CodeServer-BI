#!/bin/bash

# This script handles additional configuration needed for running in Choreo's read-only environment

# Add a note about the Choreo user
echo "Running as Choreo user (UID: ${PUID}, GID: ${PGID})"

# Make sure we can work with the Choreo user
if ! id -u ${PUID} >/dev/null 2>&1; then
    echo "Creating user with UID ${PUID} and GID ${PGID}"
    groupadd -g ${PGID} chouser 2>/dev/null || true
    useradd -u ${PUID} -g ${PGID} -m chouser 2>/dev/null || true
fi

# Create necessary directories with correct permissions
mkdir -p /tmp/config/.ssh
mkdir -p /tmp/config/workspace
mkdir -p /tmp/runtime

# Handle any environment-specific configurations
if [ -n "$PROXY_DOMAIN" ]; then
    echo "Setting up proxy domain: $PROXY_DOMAIN"
    # Add proxy configuration here
fi

# Ensure the default workspace directory exists and is writable
echo "Setting up writable workspace directory"
mkdir -p /tmp/config/workspace
chown -R ${PUID}:${PGID} /tmp/config/workspace

# Create a symlink from the read-only location if needed
if [ -d "/config/workspace" ] && [ ! -L "/config/workspace" ]; then
    echo "Copying existing workspace content to writable location"
    cp -r /config/workspace/* /tmp/config/workspace/ 2>/dev/null || true
fi

# Execute any additional commands passed to the script
exec "$@"