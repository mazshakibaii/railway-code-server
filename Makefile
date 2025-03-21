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

# Default environment variables (can be overridden from command line)
PASSWORD ?= password
GIT_REPO ?= 
DOTFILES_REPO ?=
INSTALL_APPS ?=
VS_CODE_EXTENSIONS ?=
PORT ?= 8080
PROJECT_DIR ?= $(CURDIR)/project

# Run Docker container
run:
	@echo "Running Docker container with custom environment..."
	@docker run -p $(PORT):8080 \
		-v "$(PROJECT_DIR):/home/coder/project" \
		-e PASSWORD=$(PASSWORD) \
		$(if $(GIT_REPO),-e GIT_REPO=$(GIT_REPO),) \
		$(if $(DOTFILES_REPO),-e DOTFILES_REPO=$(DOTFILES_REPO),) \
		$(if $(INSTALL_APPS),-e INSTALL_APPS=$(INSTALL_APPS),) \
		$(if $(VS_CODE_EXTENSIONS),-e VS_CODE_EXTENSIONS="$(VS_CODE_EXTENSIONS)",) \
		code-server-railway
	@echo "Container running at http://localhost:$(PORT)"

# Help message
help:
	@echo "Railway Code Server - Build Targets:"
	@echo "  make deps        - Install dependencies"
	@echo "  make build       - Build for current platform"
	@echo "  make build-linux - Build for Linux (cross-compilation)"
	@echo "  make linux       - Complete Linux build (deps + build)"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make docker      - Build Docker image (includes linux build)"
	@echo "  make run         - Run Docker container with custom environment"
	@echo ""
	@echo "Environment Variables for 'make run':"
	@echo "  PASSWORD=mypass          - Set the password (default: password)"
	@echo "  GIT_REPO=url             - Git repository to clone"
	@echo "  DOTFILES_REPO=url        - Repository with dotfiles"
	@echo "  INSTALL_APPS=app1,app2   - Comma-separated list of apps to install"
	@echo "  VS_CODE_EXTENSIONS=ext1  - VS Code extensions to install"
	@echo "  PORT=3000                - Local port to use (default: 8080)"
	@echo "  PROJECT_DIR=/path        - Local directory to mount (default: ./project)"
	@echo ""
	@echo "Example:"
	@echo "  make run PASSWORD=mysecret PORT=3000 GIT_REPO=https://github.com/user/repo.git" 