#!/bin/bash

# Script to manage Docker Compose with auto service start/stop
# Usage:
#   DockerCompose.sh up <project_name>   - Start Docker service and run docker-compose up -d
#   DockerCompose.sh down <project_name> - Run docker-compose down and stop Docker service

# Predefined project paths
declare -A PROJECTS
PROJECTS["rsa"]="~/Projects/RevSplits/auto-rsa"
PROJECTS["helprsa"]="~/Projects/RSAssistant"

# Check usage
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <up|down> <project_name>"
    echo "Available projects: ${!PROJECTS[@]}"
    exit 1
fi

ACTION=$1
PROJECT_NAME=$2

# Resolve project path
PROJECT_PATH=${PROJECTS[$PROJECT_NAME]}

if [ -z "$PROJECT_PATH" ]; then
    echo "Error: Unknown project '$PROJECT_NAME'."
    echo "Available projects: ${!PROJECTS[@]}"
    exit 1
fi

# Ensure project path exists
PROJECT_PATH=$(eval echo "$PROJECT_PATH")  # Resolve ~ to full path
if [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: Project path '$PROJECT_PATH' does not exist."
    exit 1
fi

cd "$PROJECT_PATH" || {
    echo "Failed to navigate to $PROJECT_PATH"
    exit 1
}

case "$ACTION" in
    up)
        echo "Starting Docker service..."
        sudo systemctl start docker.service
        echo "Running docker-compose up -d..."
        docker-compose up -d
        ;;
    down)
        echo "Running docker-compose down..."
        docker-compose down
        echo "Stopping Docker service..."
        sudo systemctl stop docker.service
        ;;
    *)
        echo "Invalid action. Use 'up' or 'down'."
        exit 1
        ;;
esac

