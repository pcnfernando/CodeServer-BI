#!/bin/sh
set -e

# Print some debug information
echo "Starting code-server with UID: $(id -u), GID: $(id -g)"
echo "Using workspace directory: ${DEFAULT_WORKSPACE}"

# Ensure our directories exist
mkdir -p "${DEFAULT_WORKSPACE}" /tmp/config /tmp/data /tmp/home
mkdir -p /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp

# Create a minimal config for code-server if it doesn't exist
echo "Setting up code-server configuration..."
mkdir -p /tmp/config
cat > /tmp/config/config.yaml <<EOL
bind-addr: 0.0.0.0:8443
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

echo "Starting code-server..."
# Start code-server
"$CODE_SERVER_BIN" \
  --config=/tmp/config/config.yaml \
  --user-data-dir=/tmp/data \
  --disable-telemetry \
  --disable-update-check \
  --bind-addr=0.0.0.0:8443 \
  ${DEFAULT_WORKSPACE}


# Give code-server a moment to start
sleep 2

  echo "Starting Nginx for WebSocket proxying..."
# Start Nginx in the background
exec nginx -g "daemon off;" &
NGINX_PID=$!