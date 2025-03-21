#!/bin/bash
set -e

echo "Building status server binary..."

# Change to the server directory
cd deploy-container/server

# Create bin directory if it doesn't exist
mkdir -p bin

# Initialize Go module if needed
go mod init status-server 2>/dev/null || true
go get github.com/gorilla/websocket
go mod tidy

# Build the binary
go build -o bin/status-server main.go

echo "Binary built successfully at deploy-container/server/bin/status-server"

# Make the binary executable
chmod +x bin/status-server

echo "Build completed successfully!" 