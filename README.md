# VS Code Server for Railway

A customized code-server deployment template for [Railway](https://railway.app), featuring a rapid build time with an extensible and programmable set of parameters to fine-tune your environment exactly how you want it (e.g. specify applications, runtimes, vscode extensions).

## Features

- **VS Code Anywhere**: Spin up a remote code environment and access from anywhere
- **Application Installation**: Easily install common development tools
- **VS Code Extension Support**: Pre-install your favorite extensions
- **Git Repository Integration**: Clone your project automatically on startup

## Quick Start

1. Click the button below to deploy to Railway:

   [![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/template/gsXgfZ?referralCode=tvRhO8)

2. Configure your deployment with environment variables (see below)
3. Wait for the build to complete
4. Access your code-server from the URL provided by Railway

## Configuration

Configure your environment using the following variables:

| Variable             | Description                                                                        | Example                                            |
| -------------------- | ---------------------------------------------------------------------------------- | -------------------------------------------------- |
| `PASSWORD`           | Password for accessing code-server                                                 | `your-secure-password`                             |
| `GIT_REPO`           | Repository to clone on startup                                                     | `https://github.com/username/repo.git`             |
| `INSTALL_APPS`       | Comma-separated list of apps to install                                            | `node,bun,python,go,rust,java,zig`                 |
| `VS_CODE_EXTENSIONS` | Comma-separated list of extension IDs ([OpenVSX](https://open-vsx.org/) supported) | `esbenp.prettier-vscode,bradlc.vscode-tailwindcss` |
| `DOTFILES_REPO`      | Repository with dotfiles to use                                                    | `https://github.com/username/dotfiles.git`         |
| `DOTFILES_SYMLINK`   | Whether to symlink dotfiles (true/false)                                           | `true`                                             |
| `START_DIR`          | Starting directory for code-server                                                 | `/home/coder/project`                              |
| `APP_NAME`           | Custom name for the code-server instance                                           | `My Project IDE`                                   |

## Application Support

You can install the following applications using the `INSTALL_APPS` variable:

- `node` - Node.js and NPM
- `bun` - Bun JavaScript runtime
- `go` - Go programming language
- `rust` - Rust programming language
- `java` - Java Development Kit
- `python` - Python 3 with pip and venv
- `zig` - Zig programming language

## Development Guide

### Prerequisites

- Docker
- Go (for working on the status server)
- Make

### Using the Makefile

This project includes a comprehensive Makefile that simplifies development and building tasks. Here are the main commands:

#### Go Server Development

```bash
# Set up Go modules and dependencies
make deps

# Build the Go status server for your current platform
make build

# Build the Go status server specifically for Linux
make linux

# Clean build artifacts
make clean
```

#### Docker Image Building

```bash
# Build and tag the Docker image
make docker

# Build the Docker image with a custom tag
make docker TAG=my-custom-tag

# Run the Docker container locally
make run

# Run with custom environment variables
make run PASSWORD=mysecret GIT_REPO=https://github.com/myuser/myrepo.git
```

#### Complete Rebuild

```bash
# Rebuild everything (Go binary and Docker image)
make all
```

### Manual Building (Without Make)

If you prefer not to use Make, you can manually build:

```bash
# Build the Go status server
cd deploy-container/server
go mod init status-server # If not already initialized
go get github.com/gorilla/websocket
go mod tidy
go build -o bin/status-server main.go

# Build the Docker image
docker build -t code-server-railway .

# Run the container
docker run -p 8080:8080 -e PASSWORD=your_password code-server-railway
```

## How It Works

This project enhances the standard code-server Docker image with:

1. A Go-based WebSocket server that provides real-time status updates
2. A custom loading page that displays initialization progress
3. A customized entrypoint script that handles:
   - Repository cloning
   - Application installation
   - VS Code extension installation
   - Dotfiles setup
   - Seamless transition to code-server

## Customizing the Code Server

### Modifying the Docker Image

To update your code-server version, modify the version number in your Dockerfile. See the [list of tags](https://hub.docker.com/r/codercom/code-server/tags?page=1&ordering=last_updated) for the latest version.

You can add additional dependencies in the Dockerfile:

```Dockerfile
# Install a VS Code extension
RUN code-server --install-extension esbenp.prettier-vscode

# Install apt packages
RUN sudo apt-get install -y your-package-name

# Copy custom files
COPY your-file /home/coder/your-file
```

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## Railway Deployment

This repository is designed to be deployed on Railway. Simply connect your repository to Railway and it will automatically build and deploy your code-server instance.

**Important**: Make sure to precompile the Go status server binary before pushing changes. The binary is shipped with the repository to speed up the deployment process.

## License

[MIT License](LICENSE)

## Acknowledgements

[coder/deploy-code-server](https://github.com/coder/deploy-code-server) - creating the code-server product and the initial railway build logic.
