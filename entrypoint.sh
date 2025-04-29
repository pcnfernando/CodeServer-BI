#!/bin/bash

# entrypoint.sh - Custom entrypoint for code-server in Choreo

# Print some debug information
echo "Starting code-server with UID: $(id -u), GID: $(id -g)"
echo "Using workspace directory: ${DEFAULT_WORKSPACE}"

# Ensure our directories exist
mkdir -p "${DEFAULT_WORKSPACE}" /tmp/config /tmp/data /tmp/home

# Create a minimal config for code-server if it doesn't exist
echo "Setting up code-server configuration..."
mkdir -p /tmp/config
cat > /tmp/config/config.yaml <<EOL
bind-addr: 0.0.0.0:8443
auth: password
password: ${PASSWORD:-$(date +%s | sha256sum | base64 | head -c 32)}
cert: false
EOL

# Print some helpful information
echo "code-server is starting up..."
echo "It will be available on port 8443"
echo "Default workspace is set to ${DEFAULT_WORKSPACE}"

# Find the correct code-server executable
CODE_SERVER_BIN="/usr/bin/code-server"
if [ ! -f "$CODE_SERVER_BIN" ] || [ ! -x "$CODE_SERVER_BIN" ]; then
  echo "Symlinked executable not found, searching for code-server..."
  CODE_SERVER_BIN=$(find / -name "code-server" -type f -executable 2>/dev/null | head -n 1)
fi
if [ -z "$CODE_SERVER_BIN" ]; then
  echo "ERROR: Could not find code-server executable"
  # List potential locations to help debug
  echo "Searching common locations:"
  ls -la /usr/bin/code-server 2>/dev/null || echo "Not in /usr/bin"
  ls -la /usr/local/bin/code-server 2>/dev/null || echo "Not in /usr/local/bin"
  ls -la /app/code-server 2>/dev/null || echo "Not in /app"
  
  # Try to locate using which
  WHICH_CS=$(which code-server 2>/dev/null)
  if [ ! -z "$WHICH_CS" ]; then
    echo "Found via which: $WHICH_CS"
    CODE_SERVER_BIN=$WHICH_CS
  else
    # As a fallback, use the s6 service
    echo "Attempting to use LinuxServer.io init system as fallback..."
    exec /init
  fi
fi

if [ ! -z "$CODE_SERVER_BIN" ]; then
  echo "Using code-server at: $CODE_SERVER_BIN"
  # Call code-server directly
  exec "$CODE_SERVER_BIN" --config=/tmp/config/config.yaml --user-data-dir=/tmp/data ${DEFAULT_WORKSPACE}
fi