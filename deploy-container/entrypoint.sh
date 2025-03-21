#!/bin/bash

START_DIR="${START_DIR:-/home/coder/project}"
PREFIX="deploy-code-server"
APP_NAME="${APP_NAME:-Code Server}"
LOADING_DIR="/home/coder/loading"
STATUS_FILE="$LOADING_DIR/loading-status.txt"
ENTRYPOINT_PATH=$(realpath "$0")  # Get absolute path of this script

# Create our project directory if it doesn't exist
mkdir -p $START_DIR

# Function to update status on the loading page
update_status() {
    echo "[$(date "+%H:%M:%S")] $1" >> "$STATUS_FILE"
    # Keep only the last 20 lines of the status file
    tail -n 20 "$STATUS_FILE" > "$STATUS_FILE.tmp" && mv "$STATUS_FILE.tmp" "$STATUS_FILE"
}

# Initialize the status file
echo "Initializing environment..." > "$STATUS_FILE"

# Start the status server
update_status "Starting initialization server..."
cd $LOADING_DIR  # Change to loading directory so relative paths work correctly
./status-server &
LOADING_PID=$!

# Trap to ensure we kill the loading server if the script exits unexpectedly
trap "kill $LOADING_PID 2>/dev/null" EXIT

# Function to clone the git repo or add a user's first file if no repo was specified
project_init() {
    if [ -z "${GIT_REPO}" ]; then
        update_status "No GIT_REPO specified, creating sample file"
        echo "Example file. Have questions? Join us at https://community.coder.com" > $START_DIR/coder.txt
    else
        update_status "Cloning repository: $GIT_REPO"
        # Check if directory exists and is not empty
        if [ -d "$START_DIR" ] && [ "$(ls -A $START_DIR)" ]; then
            update_status "Project directory already exists and is not empty. Skipping git clone."
        else
            git clone $GIT_REPO $START_DIR
            update_status "Repository cloned successfully"
        fi
    fi
}

# Function to install applications/runtimes
install_applications() {
    if [ -z "${INSTALL_APPS}" ]; then
        update_status "No applications specified to install"
        return
    fi

    update_status "Installing requested applications..."
    
    # Update package lists
    sudo apt-get update
    
    # Parse comma-separated list
    IFS=',' read -ra APPS <<< "$INSTALL_APPS"
    for app in "${APPS[@]}"; do
        # Trim whitespace
        app=$(echo "$app" | tr -d '[:space:]')
        
        if [ -z "$app" ]; then
            continue  # Skip empty entries
        fi
        
        case "$app" in
            "node")
                update_status "Installing Node.js..."
                sudo apt-get install -y nodejs npm
                ;;
            "bun")
                update_status "Installing Bun..."
                curl -fsSL https://bun.sh/install | bash
                # Add bun to PATH for this session
                export BUN_INSTALL="$HOME/.bun"
                export PATH="$BUN_INSTALL/bin:$PATH"
                ;;
            "go")
                update_status "Installing Go..."
                sudo apt-get install -y golang-go
                ;;
            "rust")
                update_status "Installing Rust..."
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
                # Add cargo to PATH for this session
                source "$HOME/.cargo/env"
                ;;
            "java")
                update_status "Installing Java..."
                sudo apt-get install -y default-jdk
                ;;
            "python")
                update_status "Installing Python..."
                sudo apt-get install -y python3 python3-pip python3-venv
                ;;
            "zig")
                update_status "Installing Zig..."
                # Get latest release URL
                ZIG_URL=$(curl -s https://ziglang.org/download/ | grep -o 'https://ziglang.org/download/[0-9.]*[0-9]/zig-linux-x86_64-[0-9.]*[0-9].tar.xz' | head -1)
                if [ -n "$ZIG_URL" ]; then
                    wget -O /tmp/zig.tar.xz "$ZIG_URL"
                    sudo mkdir -p /usr/local/zig
                    sudo tar -xf /tmp/zig.tar.xz -C /usr/local/zig --strip-components=1
                    sudo ln -sf /usr/local/zig/zig /usr/local/bin/
                    rm /tmp/zig.tar.xz
                else
                    update_status "Failed to find Zig download URL"
                fi
                ;;
            *)
                update_status "Unknown application: $app"
                ;;
        esac
    done
    update_status "Application installation completed"
}

# Initialize the project (clone repository or create sample file)
project_init

# Add dotfiles, if set
if [ -n "$DOTFILES_REPO" ]; then
    update_status "Cloning dotfiles from $DOTFILES_REPO"
    mkdir -p $HOME/dotfiles
    git clone $DOTFILES_REPO $HOME/dotfiles

    DOTFILES_SYMLINK="${DOTFILES_SYMLINK:-true}"

    # symlink repo to $HOME
    if [ $DOTFILES_SYMLINK = "true" ]; then
        update_status "Symlinking dotfiles to home directory"
        shopt -s dotglob
        ln -sf $HOME/dotfiles/* $HOME
    fi

    # run install script, if it exists
    if [ -f "$HOME/dotfiles/install.sh" ]; then
        update_status "Running dotfiles install script"
        $HOME/dotfiles/install.sh
    fi
    update_status "Dotfiles setup completed"
fi

# Install additional VS Code extensions if provided in VS_CODE_EXTENSIONS
if [ -n "$VS_CODE_EXTENSIONS" ]; then
    update_status "Installing additional VS Code extensions..."
    IFS=',' read -ra EXTENSIONS <<< "$VS_CODE_EXTENSIONS"
    for extension in "${EXTENSIONS[@]}"; do
        # Trim whitespace
        extension=$(echo "$extension" | tr -d '[:space:]')
        
        # Skip if extension is empty (can happen with trailing commas)
        if [ -n "$extension" ]; then
            update_status "Installing extension: $extension"
            code-server --install-extension "$extension" || update_status "Failed to install extension: $extension"
        fi
    done
    update_status "VS Code extensions installation completed"
fi

# Install requested applications/runtimes
install_applications

update_status "Environment initialization completed. Starting code-server..."

# Sleep a moment to make sure the message is visible
sleep 2

# Make sure to properly kill the loading server and release port 8080
update_status "Stopping initialization server..."
if [ -n "$LOADING_PID" ]; then
    kill $LOADING_PID
    # Wait for the process to actually terminate
    wait $LOADING_PID 2>/dev/null || true
    # Make extra sure the port is released
    sleep 1
fi

# Reset the trap
trap - EXIT

# Create a cleanup script that will delete the loading directory and this script
CLEANUP_SCRIPT=$(mktemp)
cat > $CLEANUP_SCRIPT << EOF
#!/bin/bash
# Wait a moment to ensure the code-server has started
sleep 5
# Clean up the loading directory and this entrypoint script
rm -rf $LOADING_DIR
rm -f $ENTRYPOINT_PATH
# Clean up this cleanup script itself
rm -f \$0
EOF

# Make the cleanup script executable and run it in the background
chmod +x $CLEANUP_SCRIPT
nohup $CLEANUP_SCRIPT > /dev/null 2>&1 &

# Start code-server
echo "[$PREFIX] Starting code-server..."
exec /usr/bin/entrypoint.sh --app-name $APP_NAME --bind-addr 0.0.0.0:8080 $START_DIR