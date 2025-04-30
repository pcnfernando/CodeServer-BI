#!/bin/sh
set -e

# Print some debug information
echo "Starting code-server with UID: $(id -u), GID: $(id -g)"
echo "Using workspace directory: ${DEFAULT_WORKSPACE}"
echo "Setting up code-server configuration..."

# Create directories in /tmp
mkdir -p "${DEFAULT_WORKSPACE}" /tmp/config /tmp/data /tmp/home

# Create config subdirectories that code-server needs
mkdir -p /tmp/config/.local/share/code-server
mkdir -p /tmp/config/.cache

# Ensure directories have proper permissions
chmod -R 777 /tmp/config
chmod -R 777 /tmp/data
chmod -R 777 /tmp/home
chmod -R 777 /tmp/workspace

# Set environment variables to redirect code-server data to /tmp locations
export XDG_CONFIG_HOME="/tmp/config"
export XDG_CACHE_HOME="/tmp/config/.cache"
export XDG_DATA_HOME="/tmp/config/.local/share"
export XDG_STATE_HOME="/tmp/config/.local/state"
export XDG_RUNTIME_DIR="/tmp/runtime"
export HOME="/tmp/home"

# Print environment variables for debugging
echo "Using environment variables:"
echo "XDG_CONFIG_HOME=${XDG_CONFIG_HOME}"
echo "XDG_CACHE_HOME=${XDG_CACHE_HOME}"
echo "XDG_DATA_HOME=${XDG_DATA_HOME}"
echo "HOME=${HOME}"

# Create a basic code-server config file with auth disabled
cat > /tmp/config/config.yaml <<EOL
bind-addr: 0.0.0.0:8080
auth: none
password: 
cert: false
allow-http: true
disable-telemetry: true
disable-update-check: true
EOL

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
  --disable-telemetry \
  --disable-update-check \
  --auth none \
  --bind-addr=0.0.0.0:8080 \
  --allow-http \
  "${DEFAULT_WORKSPACE}"