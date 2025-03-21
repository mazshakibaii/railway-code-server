.PHONY: build clean

# Default target
all: build

# Build the binary
build:
	@echo "Building status server binary..."
	@cd $(CURDIR) && go build -o bin/status-server main.go
	@echo "Binary built successfully: bin/status-server"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -f bin/status-server 