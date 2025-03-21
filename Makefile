.PHONY: build build-linux deps clean docker run help

# Default target
all: help

# Set up dependencies for the status server
deps:
	@echo "Setting up Go dependencies..."
	@mkdir -p deploy-container/server/bin
	@cd deploy-container/server && go mod init status-server 2>/dev/null || true
	@cd deploy-container/server && go get github.com/gorilla/websocket
	@cd deploy-container/server && go mod tidy
	@echo "Dependencies installed successfully"

# Build the status server for the current platform
build:
	@echo "Building status server for current platform..."
	@mkdir -p deploy-container/server/bin
	@cd deploy-container/server && go build -o bin/status-server main.go
	@chmod +x deploy-container/server/bin/status-server
	@echo "Binary built successfully: deploy-container/server/bin/status-server"

# Build the status server for Linux (cross-compilation)
build-linux:
	@echo "Building status server for Linux deployment..."
	@mkdir -p deploy-container/server/bin
	@cd deploy-container/server && GOOS=linux GOARCH=amd64 go build -o bin/status-server main.go
	@chmod +x deploy-container/server/bin/status-server
	@echo "Linux binary built successfully: deploy-container/server/bin/status-server"

# Complete Linux build with dependencies
linux: deps build-linux
	@echo "Linux build completed successfully"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -f deploy-container/server/bin/status-server

# Build Docker image
docker: linux
	@echo "Building Docker image..."
	@docker build -t code-server-railway .
	@echo "Docker image built successfully. Run with: make run"

# Run Docker container
run:
	@echo "Running Docker container..."
	@docker run -p 8080:8080 -e PASSWORD=password code-server-railway
	@echo "Container running at http://localhost:8080"

# Help message
help:
	@echo "Railway Code Server - Build Targets:"
	@echo "  make deps        - Install dependencies"
	@echo "  make build       - Build for current platform"
	@echo "  make build-linux - Build for Linux (cross-compilation)"
	@echo "  make linux       - Complete Linux build (deps + build)"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make docker      - Build Docker image (includes linux build)"
	@echo "  make run         - Run Docker container"
	@echo "  make help        - Show this help message" 