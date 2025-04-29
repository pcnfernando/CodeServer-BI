# Use the official LinuxServer.io code-server image
FROM lscr.io/linuxserver/code-server:latest

# Set labels for documentation
LABEL maintainer="Your Name <your.email@example.com>"
LABEL description="VS Code Server for Choreo deployment"

# Set environment variables for Choreo
ENV PUID=10500
ENV PGID=10500
ENV TZ=Etc/UTC
# You can set a password or use a hashed password
ENV PASSWORD=your_password
# ENV HASHED_PASSWORD=your_hashed_password

# Set up for Choreo's read-only filesystem by making writable directories in /tmp
# Set default workspace to writable location
ENV DEFAULT_WORKSPACE=/tmp/workspace

# Create necessary writable directories in /tmp
RUN mkdir -p /tmp/workspace /tmp/home /tmp/config /tmp/data

# Create symlinks for critical paths that need to be writable
RUN mkdir -p /config && \
    touch /.dockerenv && \
    ln -sf /tmp/config /config && \
    ln -sf /tmp/home /home/abc && \
    ln -sf /tmp/data /data

# Install gosu for easy step-down from root to Choreo user and nginx for proxy
RUN apt-get update && apt-get install -y --no-install-recommends gosu nginx && \
    rm -rf /var/lib/apt/lists/*

# Copy nginx configuration
COPY ./nginx.conf /etc/nginx/sites-available/code-server
RUN ln -sf /etc/nginx/sites-available/code-server /etc/nginx/sites-enabled/default

# Find the code-server executable path and create a symlink if needed
RUN CODE_SERVER_BIN=$(find / -name "code-server" -type f -executable 2>/dev/null | head -n 1) && \
    if [ ! -z "$CODE_SERVER_BIN" ] && [ "$CODE_SERVER_BIN" != "/usr/bin/code-server" ]; then \
        echo "Creating symlink from $CODE_SERVER_BIN to /usr/bin/code-server"; \
        ln -sf "$CODE_SERVER_BIN" /usr/bin/code-server; \
    fi

# Ensure the Choreo user has proper permissions
RUN groupadd -g 10500 chouser || true && \
    useradd -u 10500 -g 10500 -d /home/abc -m chouser || true && \
    chown -R 10500:10500 /tmp/workspace /tmp/home /tmp/config /tmp/data

# Prepare the entrypoint script
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set up port
EXPOSE 8443

# Explicitly set the user to 10500
USER 10500

# Use a custom entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Healthcheck to verify the application is running
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8443/ || exit 1