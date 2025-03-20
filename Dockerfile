# Start from the code-server Debian base image
FROM codercom/code-server:latest

USER coder

# Apply VS Code settings
COPY deploy-container/settings.json .local/share/code-server/User/settings.json

# Use bash shell
ENV SHELL=/bin/bash

# Install unzip + rclone (support for remote filesystem)
RUN sudo apt-get update && sudo apt-get install unzip -y
RUN curl https://rclone.org/install.sh | sudo bash

# Copy rclone tasks to /tmp, to potentially be used
COPY deploy-container/rclone-tasks.json /tmp/rclone-tasks.json

# Fix permissions for code-server
RUN sudo chown -R coder:coder /home/coder/.local

# Port
ENV PORT=8080
# Ensure the port is exposed
EXPOSE 8080

# Use our custom entrypoint script first
COPY deploy-container/entrypoint.sh /usr/bin/deploy-container-entrypoint.sh
COPY deploy-container/container-installs.sh /usr/bin/deploy-container-installs.sh

# Make the scripts executable
RUN sudo chmod +x /usr/bin/deploy-container-entrypoint.sh
RUN sudo chmod +x /usr/bin/deploy-container-installs.sh

# Ensure proper ownership of files
RUN sudo chown -R coder:coder /home/coder

# CMD ["/usr/bin/deploy-container-entrypoint.sh", "/usr/bin/deploy-container-installs.sh"]
ENTRYPOINT ["/usr/bin/deploy-container-entrypoint.sh"]