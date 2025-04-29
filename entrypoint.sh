#!/bin/sh
set -e

# Print some debug information
echo "Starting code-server with UID: $(id -u), GID: $(id -g)"
echo "Using workspace directory: ${DEFAULT_WORKSPACE}"

# Create directories in /tmp
mkdir -p "${DEFAULT_WORKSPACE}" /tmp/config /tmp/data /tmp/home
mkdir -p /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp

# Create config subdirectories that code-server needs
mkdir -p /tmp/config/.local/share/code-server
mkdir -p /tmp/config/.cache

# Ensure directories have proper permissions
chmod -R 777 /tmp/config

# Create a minimal config for code-server if it doesn't exist
echo "Setting up code-server configuration..."
cat > /tmp/config/config.yaml <<EOL
bind-addr: 0.0.0.0:8080
auth: password
password: ${PASSWORD:-$(date +%s | sha256sum | base64 | head -c 32)}
cert: false
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

# Set environment variables to redirect code-server data to /tmp locations
export XDG_CONFIG_HOME="/tmp/config"
export XDG_CACHE_HOME="/tmp/config/.cache"
export XDG_DATA_HOME="/tmp/config/.local/share"
export XDG_STATE_HOME="/tmp/config/.local/state"
export XDG_RUNTIME_DIR="/tmp/runtime"
export HOME="/tmp/home"

# Debug message showing environment variables
echo "Using environment variables:"
echo "XDG_CONFIG_HOME=${XDG_CONFIG_HOME}"
echo "XDG_CACHE_HOME=${XDG_CACHE_HOME}"
echo "XDG_DATA_HOME=${XDG_DATA_HOME}"
echo "HOME=${HOME}"

echo "Starting code-server on port 8080..."
# Start code-server in the background with redirected paths
"$CODE_SERVER_BIN" \
  --config=/tmp/config/config.yaml \
  --user-data-dir=/tmp/data \
  --disable-telemetry \
  --disable-update-check \
  --bind-addr=0.0.0.0:8080 \
  "${DEFAULT_WORKSPACE}" &

CODE_SERVER_PID=$!

# Give code-server a moment to start
sleep 3

# Check if code-server started successfully
if kill -0 $CODE_SERVER_PID 2>/dev/null; then
  echo "✅ code-server started successfully (PID: $CODE_SERVER_PID)"
else
  echo "❌ code-server failed to start"
  exit 1
fi

echo "Starting Nginx for WebSocket proxying on port 8443..."
# Start Nginx in the foreground
exec nginx -g "daemon off;"
r: 0.0.0.0:8080
auth: password
password: ${PASSWORD:-$(date +%s | sha256sum | base64 | head -c 32)}
cert: false
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

echo "Starting code-server on port 8080..."
# Start code-server in the background
"$CODE_SERVER_BIN" \
  --config=/tmp/config/config.yaml \
  --user-data-dir=/tmp/data \
  --disable-telemetry \
  --disable-update-check \
  --bind-addr=0.0.0.0:8080 \
  "${DEFAULT_WORKSPACE}" &

CODE_SERVER_PID=$!

# Give code-server a moment to start
sleep 2

# Check if code-server started successfully
if kill -0 $CODE_SERVER_PID 2>/dev/null; then
  echo "✅ code-server started successfully (PID: $CODE_SERVER_PID)"
else
  echo "❌ code-server failed to start"
  exit 1
fi

echo "Starting Nginx for WebSocket proxying on port 8443..."
# Start Nginx in the foreground
exec nginx -g "daemon off;"