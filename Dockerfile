# Start with the code-server base image
FROM codercom/code-server:latest

USER root

# Install dependencies & tools
RUN apt-get update && apt-get install -y \
    curl \
    git \
    ripgrep \
    python3 \
    python3-pip \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Set up directories
RUN mkdir -p /home/coder/loading
WORKDIR /home/coder

# Copy in loading page and the prebuilt status server binary
COPY deploy-container/loading.html /home/coder/loading/loading.html
COPY deploy-container/server/bin/status-server /home/coder/loading/status-server

# Set up the entrypoint file
COPY deploy-container/entrypoint.sh /home/coder/entrypoint.sh
COPY deploy-container/rclone-tasks.json /tmp/rclone-tasks.json

# Fix permissions
RUN chmod +x /home/coder/entrypoint.sh \
    && chmod +x /home/coder/loading/status-server \
    && chown -R coder:coder /home/coder

USER coder

# Set the default environment variables
ENV PORT=8080
EXPOSE 8080

# Set your custom entrypoint
ENTRYPOINT ["/home/coder/entrypoint.sh"]