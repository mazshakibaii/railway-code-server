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

# You can add custom software and dependencies for your environment below
# -----------

# # Install a VS Code extension:
# # Note: we use a different marketplace than VS Code. See https://github.com/cdr/code-server/blob/main/docs/FAQ.md#differences-compared-to-vs-code
# RUN code-server --install-extension esbenp.prettier-vscode 
# RUN code-server --install-extension rooveterinaryinc.roo-cline
# RUN code-server --install-extension bradlc.vscode-tailwindcss

# # Install apt packages:
# RUN sudo apt-get install -y nodejs

# RUN curl -fsSL https://bun.sh/install | bash

# # Use the full path to bun executable instead of relying on PATH
# RUN /home/coder/.bun/bin/bun install -g git-cz commitizen

# Port
ENV PORT=8080
# Ensure the port is exposed
EXPOSE 8080

# Use our custom entrypoint script first
COPY deploy-container/entrypoint.sh /usr/bin/deploy-container-entrypoint.sh

# Make the entrypoint script executable
RUN sudo chmod +x /usr/bin/deploy-container-entrypoint.sh
# Ensure proper ownership of files
RUN sudo chown -R coder:coder /home/coder

ENTRYPOINT ["/usr/bin/deploy-container-entrypoint.sh"]