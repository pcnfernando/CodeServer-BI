#!/bin/bash
set -e

# Copy template project to workspace
if [ -d "/opt/project-template" ] && [ -d "${DEFAULT_WORKSPACE}" ]; then
    echo "Copying project template to workspace..."
    cp -r /opt/project-template/* ${DEFAULT_WORKSPACE}/
fi

# Set up extensions directory symlink for the user
mkdir -p /tmp/config/.local/share/code-server/extensions
ln -sf /opt/code-server/extensions/* /tmp/config/.local/share/code-server/extensions/

# Set environment variables
export JAVA_HOME=/opt/java/jdk-21.0.5+11
export PATH=$JAVA_HOME/bin:$PATH

# Execute original entrypoint
exec /usr/local/bin/entrypoint.sh