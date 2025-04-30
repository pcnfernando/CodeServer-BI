# Use the official LinuxServer.io code-server image
FROM lscr.io/linuxserver/code-server:latest

# Set labels for documentation
LABEL maintainer="pcnfernando@gmail.com>"
LABEL description="VS Code Server for Devant with Ballerina support"

# Set environment variables for Devant
ENV PUID=10500
ENV PGID=10500
ENV TZ=Etc/UTC
# No password needed since we're using auth: none
ENV PASSWORD=""
ENV DEFAULT_WORKSPACE=/tmp/workspace

# Switch to root to install packages
USER root

# Install required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    curl \
    iputils-ping \
    net-tools \
    procps \
    maven \
    unzip \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create necessary writable directories in /tmp
RUN mkdir -p /tmp/workspace /tmp/home /tmp/config /tmp/data

# Download Ballerina
RUN curl -o /tmp/ballerina-2201.12.3-swan-lake-linux-x64.deb https://dist.ballerina.io/downloads/2201.12.3/ballerina-2201.12.3-swan-lake-linux-x64.deb

# Download VSCode extensions
RUN curl --compressed -L -o /tmp/wso2.ballerina-integrator-1.0.0.vsix "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/wso2/vsextensions/ballerina-integrator/1.0.0/vspackage" \
    && curl --compressed -L -o /tmp/wso2.ballerina-5.1.0.vsix "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/wso2/vsextensions/ballerina/5.1.0/vspackage" \
    && curl --compressed -L -o /tmp/anweber.httpbook-3.2.6.vsix "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/anweber/vsextensions/httpbook/3.2.6/vspackage" \
    && curl --compressed -L -o /tmp/anweber.vscode-httpyac-6.16.7.vsix "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/anweber/vsextensions/vscode-httpyac/6.16.7/vspackage" \
    && curl --compressed -L -o /tmp/wso2.wso2-platform-1.0.11.vsix "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/wso2/vsextensions/wso2-platform/1.0.11/vspackage" \
    && curl --compressed -L -o /tmp/redhat.vscode-yaml-1.17.0.vsix "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/redhat/vsextensions/vscode-yaml/1.17.0/vspackage" \
    && curl --compressed -L -o /tmp/be5invis.toml-0.6.0.vsix "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/be5invis/vsextensions/toml/0.6.0/vspackage"

# Download and setup Java
RUN mkdir -p /opt/java \
    && curl -L -o /tmp/OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.5%2B11/OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz" \
    && tar -xvzf /tmp/OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz -C /opt/java \
    && rm /tmp/OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz

# Install Ballerina
RUN dpkg -i /tmp/ballerina-2201.12.3-swan-lake-linux-x64.deb \
    && rm /tmp/ballerina-2201.12.3-swan-lake-linux-x64.deb

# Set up environment variables for Java
ENV JAVA_HOME=/opt/java/jdk-21.0.5+11
ENV PATH=$JAVA_HOME/bin:$PATH

# Create symlinks for critical paths that need to be writable
RUN mkdir -p /config && \
    touch /.dockerenv && \
    ln -sf /tmp/config /config && \
    ln -sf /tmp/home /home/abc && \
    ln -sf /tmp/data /data

# Find the code-server executable path and create a symlink if needed
RUN CODE_SERVER_BIN=$(find / -name "code-server" -type f -executable 2>/dev/null | head -n 1) && \
    if [ ! -z "$CODE_SERVER_BIN" ] && [ "$CODE_SERVER_BIN" != "/usr/bin/code-server" ]; then \
        echo "Creating symlink from $CODE_SERVER_BIN to /usr/bin/code-server"; \
        ln -sf "$CODE_SERVER_BIN" /usr/bin/code-server; \
    fi

# Create a sample project with Ballerina
RUN mkdir -p /opt/project-template \
    && git clone https://github.com/manuranga/ballerina-integrator-empty-proj.git /tmp/ballerina-integrator-empty-proj \
    && cp -r /tmp/ballerina-integrator-empty-proj/1.0.0/* /opt/project-template/ \
    && rm -rf /tmp/ballerina-integrator-empty-proj

# Pre-install VS Code extensions to the global location
RUN mkdir -p /opt/code-server/extensions \
    && code-server --extensions-dir=/opt/code-server/extensions --install-extension /tmp/wso2.ballerina-5.1.0.vsix \
    && code-server --extensions-dir=/opt/code-server/extensions --install-extension /tmp/wso2.ballerina-integrator-1.0.0.vsix \
    && code-server --extensions-dir=/opt/code-server/extensions --install-extension /tmp/anweber.httpbook-3.2.6.vsix \
    && code-server --extensions-dir=/opt/code-server/extensions --install-extension /tmp/anweber.vscode-httpyac-6.16.7.vsix \
    && code-server --extensions-dir=/opt/code-server/extensions --install-extension /tmp/wso2.wso2-platform-1.0.11.vsix \
    && code-server --extensions-dir=/opt/code-server/extensions --install-extension /tmp/redhat.vscode-yaml-1.17.0.vsix \
    && code-server --extensions-dir=/opt/code-server/extensions --install-extension /tmp/be5invis.toml-0.6.0.vsix \
    && rm -rf /tmp/*.vsix

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

# Ensure the Devant user has proper permissions
RUN groupadd -g 10500 chouser || true && \
    useradd -u 10500 -g 10500 -d /home/abc -m chouser || true && \
    chown -R 10500:10500 /tmp/workspace /tmp/home /tmp/config /tmp/data /opt/code-server/extensions

# Copy the setup script
COPY ./setup-environment.sh /usr/local/bin/setup-environment.sh
COPY ./entrypoint.sh /usr/local/bin/entrypoint.sh

# Ensure the setup script has correct line endings and is executable
RUN sed -i 's/\r$//' /usr/local/bin/setup-environment.sh && \
    chmod +x /usr/local/bin/setup-environment.sh && \
    chown 10500:10500 /usr/local/bin/setup-environment.sh

# Ensure the entrypoint script has correct line endings and is executable
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh && \
    chown 10500:10500 /usr/local/bin/entrypoint.sh

# Set up port
EXPOSE 8443

# Explicitly set the user to 10500
USER 10500

# Use a custom entrypoint
ENTRYPOINT ["/usr/local/bin/setup-environment.sh"]

# Healthcheck to verify the application is running
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8443/ || exit 1