#!/bin/sh
set -e

# Print some debug information
echo "Starting code-server with UID: $(id -u), GID: $(id -g)"
echo "Using workspace directory: ${DEFAULT_WORKSPACE}"
echo "Setting up code-server configuration..."

# Create directories in /tmp
mkdir -p "${DEFAULT_WORKSPACE}" /tmp/config /tmp/data /tmp/home /tmp/extensions

# Create config subdirectories that code-server needs
mkdir -p /tmp/config/.local/share/code-server
mkdir -p /tmp/config/.cache
mkdir -p /tmp/runtime

# Copy the Ballerina template project to workspace if it's empty
if [ -z "$(ls -A ${DEFAULT_WORKSPACE} 2>/dev/null)" ]; then
    echo "Initializing workspace with Ballerina template project..."
    cp -r /opt/ballerina-template/1.0.0/* "${DEFAULT_WORKSPACE}/"
fi

# Ensure directories have proper permissions
chmod -R 777 /tmp/config
chmod -R 777 /tmp/data
chmod -R 777 /tmp/home
chmod -R 777 /tmp/workspace
chmod -R 777 /tmp/extensions
chmod -R 777 /tmp/runtime

# Set environment variables to redirect code-server data to /tmp locations
export XDG_CONFIG_HOME="/tmp/config"
export XDG_CACHE_HOME="/tmp/config/.cache"
export XDG_DATA_HOME="/tmp/config/.local/share"
export XDG_STATE_HOME="/tmp/config/.local/state"
export XDG_RUNTIME_DIR="/tmp/runtime"
export HOME="/tmp/home"
export BALLERINA_HOME="/opt/ballerina"

# Add Java and Ballerina to PATH
export PATH="$JAVA_HOME/bin:$BALLERINA_HOME/bin:$PATH"

# Print environment variables for debugging
echo "Using environment variables:"
echo "XDG_CONFIG_HOME=${XDG_CONFIG_HOME}"
echo "XDG_CACHE_HOME=${XDG_CACHE_HOME}"
echo "XDG_DATA_HOME=${XDG_DATA_HOME}"
echo "HOME=${HOME}"
echo "JAVA_HOME=${JAVA_HOME}"
echo "BALLERINA_HOME=${BALLERINA_HOME}"
echo "PATH=${PATH}"

# Create a basic code-server config file with auth disabled
cat > /tmp/config/config.yaml <<EOL
bind-addr: 0.0.0.0:8080
auth: none
password: 
cert: false
disable-telemetry: true
disable-update-check: true
extensions-dir: /tmp/extensions
user-data-dir: /tmp/data
EOL

# Link the system extensions to the temp extensions directory
echo "Setting up extensions from system directory..."
if [ -d "/usr/lib/code-server/extensions" ]; then
    for ext in /usr/lib/code-server/extensions/*; do
        if [ -d "$ext" ]; then
            ext_name=$(basename "$ext")
            echo "Linking extension: $ext_name"
            ln -sf "$ext" "/tmp/extensions/$ext_name"
        fi
    done
fi

# Find the correct code-server executable
CODE_SERVER_BIN="/usr/bin/code-server"
if [ ! -f "$CODE_SERVER_BIN" ] || [ ! -x "$CODE_SERVER_BIN" ]; then
  echo "Symlinked executable not found, searching for code-server..."
  CODE_SERVER_BIN=$(find / -name "code-server" -type f -executable 2>/dev/null | head -n 1)
fi

if [ -z "$CODE_SERVER_BIN" ]; then
  echo "ERROR: Could not find code-server executable"
  exit 1
fi

# Print the version info for debugging
"$CODE_SERVER_BIN" --version

# Start code-server directly in foreground mode
echo "Starting code-server on port 8080 with auth disabled for WebSockets..."
exec "$CODE_SERVER_BIN" \
  --config=/tmp/config/config.yaml \
  --user-data-dir=/tmp/data \
  --extensions-dir=/tmp/extensions \
  --disable-telemetry \
  --disable-update-check \
  --auth none \
  --bind-addr=0.0.0.0:8080 \
  "${DEFAULT_WORKSPACE}"