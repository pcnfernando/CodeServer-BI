#!/bin/sh
set -e

# Print some debug information
echo "Starting code-server with UID: $(id -u), GID: $(id -g)"
echo "Using workspace directory: ${DEFAULT_WORKSPACE}"
echo "Setting up code-server configuration..."

# Create directories in /tmp
mkdir -p "${DEFAULT_WORKSPACE}" /tmp/config /tmp/data /tmp/home
mkdir -p /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp

# Create config subdirectories that code-server needs
mkdir -p /tmp/config/.local/share/code-server
mkdir -p /tmp/config/.cache

# Create a writable log directory in /tmp for nginx
mkdir -p /tmp/nginx/logs
mkdir -p /tmp/nginx/conf
chmod -R 777 /tmp/nginx

# Create runtime directory with proper permissions for IPC sockets
 mkdir -p /tmp/runtime
 chmod 777 /tmp/runtime

# Copy nginx configuration files to the writable location
cp /etc/nginx/nginx.conf /tmp/nginx/conf/
cp /etc/nginx/mime.types /tmp/nginx/conf/

# Update the include path in the nginx.conf file to point to the new location
sed -i 's|include[[:space:]]*mime.types;|include /tmp/nginx/conf/mime.types;|g' /tmp/nginx/conf/nginx.conf

# Ensure directories have proper permissions
chmod -R 777 /tmp/config
chmod -R 777 /tmp/data
chmod -R 777 /tmp/home
chmod -R 777 "${DEFAULT_WORKSPACE}"

# Set up symlink for extensions
if [ -d "/opt/code-server/extensions" ]; then
  mkdir -p /tmp/config/.local/share/code-server/extensions
  echo "Setting up extensions from global location..."
  for ext in /opt/code-server/extensions/*; do
    if [ -d "$ext" ]; then
      ln -sf "$ext" /tmp/config/.local/share/code-server/extensions/
    fi
  done
fi

# Copy project template if workspace is empty
if [ -d "/opt/project-template" ] && [ -z "$(ls -A ${DEFAULT_WORKSPACE} 2>/dev/null)" ]; then
  echo "Copying Ballerina project template to workspace..."
  cp -r /opt/project-template/* "${DEFAULT_WORKSPACE}/"
fi

# Set environment variables to redirect code-server data to /tmp locations
export XDG_CONFIG_HOME="/tmp/config"
export XDG_CACHE_HOME="/tmp/config/.cache"
export XDG_DATA_HOME="/tmp/config/.local/share"
export XDG_STATE_HOME="/tmp/config/.local/state"
export XDG_RUNTIME_DIR="/tmp/runtime"
export HOME="/tmp/home"

# Set Java and Ballerina environment variables
export JAVA_HOME=/opt/java/jdk-21.0.5+11
export PATH=$JAVA_HOME/bin:$PATH

# Print environment variables for debugging
echo "Using environment variables:"
echo "XDG_CONFIG_HOME=${XDG_CONFIG_HOME}"
echo "XDG_CACHE_HOME=${XDG_CACHE_HOME}"
echo "XDG_DATA_HOME=${XDG_DATA_HOME}"
echo "HOME=${HOME}"
echo "JAVA_HOME=${JAVA_HOME}"

# Create a basic code-server config file - CRITICAL: auth set to none
cat > /tmp/config/config.yaml <<EOL
bind-addr: 0.0.0.0:8080
auth: none
password: 
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

# Set up correct temp locations for nginx
touch /tmp/nginx.pid
chmod 666 /tmp/nginx.pid

# Configure code-server settings for Ballerina
mkdir -p /tmp/config/Machine
cat > /tmp/config/Machine/settings.json <<EOL
{
    "ballerina.home": "/usr/lib/ballerina",
    "ballerina.plugin.firststart": false,
    "ballerina.debugLog": false,
    "editor.rulers": [120],
    "java.home": "${JAVA_HOME}"
}
EOL

# Start code-server in the background with redirected paths
echo "Starting code-server on port 8080 with auth disabled for WebSockets..."
"$CODE_SERVER_BIN" \
  --config=/tmp/config/config.yaml \
  --user-data-dir=/tmp/data \
  --extensions-dir=/tmp/config/.local/share/code-server/extensions \
  --disable-telemetry \
  --disable-update-check \
  --auth none \
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

# Start Nginx in the foreground using our config from /tmp
echo "Starting Nginx for WebSocket proxying on port 8443..."
exec nginx -c /tmp/nginx/conf/nginx.conf -g "daemon off;"