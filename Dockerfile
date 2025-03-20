# Start from the code-server Debian base image
FROM codercom/code-server:latest

USER coder

# Apply VS Code settings
COPY deploy-container/settings.json .local/share/code-server/User/settings.json

# Use bash shell
ENV SHELL=/bin/bash

# Install unzip + rclone (support for remote filesystem)
RUN sudo apt-get update && sudo apt-get install unzip python3 -y
RUN curl https://rclone.org/install.sh | sudo bash

# Copy rclone tasks to /tmp, to potentially be used
COPY deploy-container/rclone-tasks.json /tmp/rclone-tasks.json

# Create loading page
RUN mkdir -p /home/coder/loading && \
    echo '<!DOCTYPE html>\
<html lang="en">\
<head>\
    <meta charset="UTF-8">\
    <meta name="viewport" content="width=device-width, initial-scale=1.0">\
    <title>Code Server Loading</title>\
    <style>\
        body {\
            font-family: Arial, sans-serif;\
            background-color: #1e1e1e;\
            color: #e0e0e0;\
            display: flex;\
            justify-content: center;\
            align-items: center;\
            height: 100vh;\
            margin: 0;\
            flex-direction: column;\
        }\
        .loader {\
            border: 16px solid #3e3e3e;\
            border-radius: 50%;\
            border-top: 16px solid #0078d4;\
            width: 120px;\
            height: 120px;\
            animation: spin 2s linear infinite;\
            margin-bottom: 30px;\
        }\
        @keyframes spin {\
            0% { transform: rotate(0deg); }\
            100% { transform: rotate(360deg); }\
        }\
        .status {\
            margin-top: 20px;\
            font-size: 18px;\
            text-align: center;\
            max-width: 80%;\
        }\
        .log {\
            margin-top: 30px;\
            padding: 15px;\
            background-color: #2d2d2d;\
            border-radius: 5px;\
            width: 80%;\
            max-width: 600px;\
            height: 200px;\
            overflow-y: auto;\
            font-family: monospace;\
            font-size: 14px;\
        }\
        .refresh {\
            margin-top: 20px;\
            padding: 10px 15px;\
            background-color: #0078d4;\
            border: none;\
            color: white;\
            border-radius: 4px;\
            cursor: pointer;\
        }\
    </style>\
</head>\
<body>\
    <div class="loader"></div>\
    <h1>Code Server is Initializing</h1>\
    <div class="status">Please wait while your environment is being prepared. This may take a few minutes.</div>\
    <div class="log" id="log">Loading status...</div>\
    <button class="refresh" onclick="window.location.reload()">Refresh Status</button>\
    <script>\
        // Auto-refresh the page every 10 seconds\
        setTimeout(function() {\
            window.location.reload();\
        }, 10000);\
        \
        // Fetch the latest logs\
        fetch("/loading-status.txt")\
            .then(response => response.text())\
            .then(data => {\
                document.getElementById("log").innerText = data;\
            })\
            .catch(err => {\
                document.getElementById("log").innerText = "Error loading status. Please try refreshing.";\
            });\
    </script>\
</body>\
</html>' > /home/coder/loading/index.html

# Create a Python script that serves the loading page
RUN echo '#!/usr/bin/env python3
import http.server
import socketserver
import os
import sys

PORT = 8080

class LoadingHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory="/home/coder/loading", **kwargs)
    
    def log_message(self, format, *args):
        # Suppress log messages
        return

def run_server():
    with socketserver.TCPServer(("", PORT), LoadingHandler) as httpd:
        print(f"Serving loading page at port {PORT}")
        httpd.serve_forever()

if __name__ == "__main__":
    run_server()
' > /home/coder/loading/server.py && \
chmod +x /home/coder/loading/server.py

# Fix permissions for code-server
RUN sudo chown -R coder:coder /home/coder/.local

# Port
ENV PORT=8080
# Ensure the port is exposed
EXPOSE 8080

# Use our custom entrypoint script first
COPY deploy-container/entrypoint.sh /usr/bin/deploy-container-entrypoint.sh

# Make the scripts executable
RUN sudo chmod +x /usr/bin/deploy-container-entrypoint.sh

# Ensure proper ownership of files
RUN sudo chown -R coder:coder /home/coder

ENTRYPOINT ["/usr/bin/deploy-container-entrypoint.sh"]