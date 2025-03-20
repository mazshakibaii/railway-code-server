# function to clone the git repo or add a user's first file if no repo was specified.
project_init () {
    [ -z "${GIT_REPO}" ] && echo "[$PREFIX] No GIT_REPO specified" && echo "Example file. Have questions? Join us at https://community.coder.com" > $START_DIR/coder.txt || git clone $GIT_REPO $START_DIR
}

# Function to install applications/runtimes
install_applications() {
    if [ -z "${INSTALL_APPS}" ]; then
        echo "[$PREFIX] No applications specified to install"
        return
    fi

    echo "[$PREFIX] Installing requested applications..."
    
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
        
        echo "[$PREFIX] Installing $app..."
        case "$app" in
            "node")
                echo "[$PREFIX] Installing Node.js..."
                sudo apt-get install -y nodejs npm
                ;;
            "bun")
                echo "[$PREFIX] Installing Bun..."
                curl -fsSL https://bun.sh/install | bash
                # Add bun to PATH for this session
                export BUN_INSTALL="$HOME/.bun"
                export PATH="$BUN_INSTALL/bin:$PATH"
                ;;
            "go")
                echo "[$PREFIX] Installing Go..."
                sudo apt-get install -y golang-go
                ;;
            "rust")
                echo "[$PREFIX] Installing Rust..."
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
                # Add cargo to PATH for this session
                source "$HOME/.cargo/env"
                ;;
            "java")
                echo "[$PREFIX] Installing Java..."
                sudo apt-get install -y default-jdk
                ;;
            "python")
                echo "[$PREFIX] Installing Python..."
                sudo apt-get install -y python3 python3-pip python3-venv
                ;;
            "zig")
                echo "[$PREFIX] Installing Zig..."
                # Get latest release URL
                ZIG_URL=$(curl -s https://ziglang.org/download/ | grep -o 'https://ziglang.org/download/[0-9.]*[0-9]/zig-linux-x86_64-[0-9.]*[0-9].tar.xz' | head -1)
                if [ -n "$ZIG_URL" ]; then
                    wget -O /tmp/zig.tar.xz "$ZIG_URL"
                    sudo mkdir -p /usr/local/zig
                    sudo tar -xf /tmp/zig.tar.xz -C /usr/local/zig --strip-components=1
                    sudo ln -sf /usr/local/zig/zig /usr/local/bin/
                    rm /tmp/zig.tar.xz
                else
                    echo "[$PREFIX] Failed to find Zig download URL"
                fi
                ;;
            *)
                echo "[$PREFIX] Unknown application: $app"
                ;;
        esac
    done
}

# add rclone config and start rclone, if supplied
if [[ -z "${RCLONE_DATA}" ]]; then
    echo "[$PREFIX] RCLONE_DATA is not specified. Files will not persist"

    # start the project
    project_init

else
    echo "[$PREFIX] Copying rclone config..."
    mkdir -p /home/coder/.config/rclone/
    touch /home/coder/.config/rclone/rclone.conf
    echo $RCLONE_DATA | base64 -d > /home/coder/.config/rclone/rclone.conf

    # default to true
    RCLONE_VSCODE_TASKS="${RCLONE_VSCODE_TASKS:-true}"
    RCLONE_AUTO_PUSH="${RCLONE_AUTO_PUSH:-true}"
    RCLONE_AUTO_PULL="${RCLONE_AUTO_PULL:-true}"

    if [ $RCLONE_VSCODE_TASKS = "true" ]; then
        # copy our tasks config to VS Code
        echo "[$PREFIX] Applying VS Code tasks for rclone"
        cp /tmp/rclone-tasks.json /home/coder/.local/share/code-server/User/tasks.json
        # install the extension to add to menu bar
        code-server --install-extension actboy168.tasks&
    else
        # user specified they don't want to apply the tasks
        echo "[$PREFIX] Skipping VS Code tasks for rclone"
    fi



    # Full path to the remote filesystem
    RCLONE_REMOTE_PATH=${RCLONE_REMOTE_NAME:-code-server-remote}:${RCLONE_DESTINATION:-code-server-files}
    RCLONE_SOURCE_PATH=${RCLONE_SOURCE:-$START_DIR}
    echo "rclone sync $RCLONE_SOURCE_PATH $RCLONE_REMOTE_PATH $RCLONE_FLAGS -vv" > /home/coder/push_remote.sh
    echo "rclone sync $RCLONE_REMOTE_PATH $RCLONE_SOURCE_PATH $RCLONE_FLAGS -vv" > /home/coder/pull_remote.sh
    chmod +x push_remote.sh pull_remote.sh

    if rclone ls $RCLONE_REMOTE_PATH; then

        if [ $RCLONE_AUTO_PULL = "true" ]; then
            # grab the files from the remote instead of running project_init()
            echo "[$PREFIX] Pulling existing files from remote..."
            /home/coder/pull_remote.sh&
        else
            # user specified they don't want to apply the tasks
            echo "[$PREFIX] Auto-pull is disabled"
        fi

    else

        if [ $RCLONE_AUTO_PUSH = "true" ]; then
            # we need to clone the git repo and sync
            echo "[$PREFIX] Pushing initial files to remote..."
            project_init
            /home/coder/push_remote.sh&
        else
            # user specified they don't want to apply the tasks
            echo "[$PREFIX] Auto-push is disabled"
        fi

    fi

fi

# Add dotfiles, if set
if [ -n "$DOTFILES_REPO" ]; then
    # grab the files from the remote instead of running project_init()
    echo "[$PREFIX] Cloning dotfiles..."
    mkdir -p $HOME/dotfiles
    git clone $DOTFILES_REPO $HOME/dotfiles

    DOTFILES_SYMLINK="${RCLONE_AUTO_PULL:-true}"

    # symlink repo to $HOME
    if [ $DOTFILES_SYMLINK = "true" ]; then
        shopt -s dotglob
        ln -sf source_file $HOME/dotfiles/* $HOME
    fi

    # run install script, if it exists
    [ -f "$HOME/dotfiles/install.sh" ] && $HOME/dotfiles/install.sh
fi

# Install additional VS Code extensions if provided in VS_CODE_EXTENSIONS
# MUST be listed on https://open-vsx.org/ to work.
if [ -n "$VS_CODE_EXTENSIONS" ]; then
    echo "[$PREFIX] Installing additional VS Code extensions..."
    IFS=',' read -ra EXTENSIONS <<< "$VS_CODE_EXTENSIONS"
    for extension in "${EXTENSIONS[@]}"; do
        # Trim whitespace
        extension=$(echo "$extension" | tr -d '[:space:]')
        
        # Skip if extension is empty (can happen with trailing commas)
        if [ -n "$extension" ]; then
            echo "[$PREFIX] Installing extension: $extension"
            code-server --install-extension "$extension" || echo "[$PREFIX] Failed to install extension: $extension"
        fi
    done
fi

# Install requested applications/runtimes
install_applications