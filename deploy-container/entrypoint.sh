#!/bin/bash

START_DIR="${START_DIR:-/home/coder/project}"

PREFIX="deploy-code-server"

# Set default APP_NAME if not provided
APP_NAME="${APP_NAME:-Code Server}"

mkdir -p $START_DIR

echo "[$PREFIX] Starting code-server..."
# Now we can run code-server with the default entrypoint
/usr/bin/entrypoint.sh --app-name $APP_NAME --bind-addr 0.0.0.0:8080 $START_DIR