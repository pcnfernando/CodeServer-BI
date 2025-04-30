# Use the official LinuxServer.io code-server image
FROM lscr.io/linuxserver/code-server:latest

# Set labels for documentation
LABEL maintainer="Your Name <your.email@example.com>"
LABEL description="VS Code Server for Choreo deployment"

# Set environment variables for Choreo
ENV PUID=10500
ENV PGID=10500
ENV TZ=Etc/UTC
# No password needed since we're using auth: none
ENV PASSWORD=""
ENV DEFAULT_WORKSPACE=/tmp/workspace

# Create necessary writable directories in /tmp
RUN mkdir -p /tmp/workspace /tmp/home /tmp/config /tmp/data

# Create symlinks for critical paths that need to be writable
RUN mkdir -p /config && \
    touch /.dockerenv && \
    ln -sf /tmp/config /config && \
    ln -sf /tmp/home /home/abc && \
    ln -sf /tmp/data /data

# Install nginx and debug tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    curl \
    iputils-ping \
    net-tools \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Find the code-server executable path and create a symlink if needed
RUN CODE_SERVER_BIN=$(find / -name "code-server" -type f -executable 2>/dev/null | head -n 1) && \
    if [ ! -z "$CODE_SERVER_BIN" ] && [ "$CODE_SERVER_BIN" != "/usr/bin/code-server" ]; then \
        echo "Creating symlink from $CODE_SERVER_BIN to /usr/bin/code-server"; \
        ln -sf "$CODE_SERVER_BIN" /usr/bin/code-server; \
    fi

# Set up nginx directories with proper permissions
RUN mkdir -p /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp && \
    touch /tmp/nginx.pid && \
    chown -R 10500:10500 /tmp && \
    chmod -R 777 /tmp && \
    chmod 666 /tmp/nginx.pid

# Copy nginx configuration files to the standard location
# They will be copied to /tmp at runtime
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./mime.types /etc/nginx/mime.types

# Ensure the Choreo user has proper permissions
RUN groupadd -g 10500 chouser || true && \
    useradd -u 10500 -g 10500 -d /home/abc -m chouser || true && \
    chown -R 10500:10500 /tmp/workspace /tmp/home /tmp/config /tmp/data

# Prepare the entrypoint script
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh
# Ensure the entrypoint script has correct line endings and is executable
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh && \
    chown 10500:10500 /usr/local/bin/entrypoint.sh

# Set up port
EXPOSE 8443

# Explicitly set the user to 10500
USER 10500

# Use a custom entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Healthcheck to verify the application is running
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8443/ || exit 1