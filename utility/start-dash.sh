#!/usr/bin/env bash
set -euo pipefail

# Configuration
PROJECT_DIR="${HOME}/Projects/pyNance"
BACKEND_DIR="backend"
FRONTEND_DIR="frontend"
VENV_DIR=".venv"

# Helper function for displaying error messages
error() {
  echo "Error: $1" >&2
  exit 1
}

# Go to the project root directory.
if [ -d "${PROJECT_DIR}" ]; then
  cd "${PROJECT_DIR}"
  echo "Changed directory to ${PROJECT_DIR}"
else
  error "Project directory ${PROJECT_DIR} not found."
fi

# Activate the virtual environment if it exists.
if [ -d "${VENV_DIR}" ]; then
  echo "Activating virtual environment: ${VENV_DIR}"
  source "${VENV_DIR}/bin/activate"
else
  echo "Virtual environment ${VENV_DIR} not found. Continuing without activation."
fi

# Start the backend process.
if [ -d "${BACKEND_DIR}" ]; then
  cd "${BACKEND_DIR}"
  echo "Entering ${BACKEND_DIR} directory."

  # Kill any flask processes that may already be running.
  echo "Killing any running Flask processes..."
  pkill -f flask || true

  echo "Starting Flask server..."
  flask run &
  FLASK_PID=$!
  echo "Flask server started in background (PID: ${FLASK_PID})."

  # Return to project root.
  cd ..
else
  echo "Directory ${BACKEND_DIR} not found. Skipping backend startup."
fi

# Start the frontend process.
if [ -d "${FRONTEND_DIR}" ]; then
  cd "${FRONTEND_DIR}"
  echo "Entering ${FRONTEND_DIR} directory."

  # Kill any running npm processes.
  echo "Killing any running npm processes..."
  pkill -f npm || true

  echo "Starting npm development server..."
  npm run dev &
  NPM_PID=$!
  echo "NPM development server started in background (PID: ${NPM_PID})."

  # Return to project root.
  cd ..
else
  echo "Directory ${FRONTEND_DIR} not found. Skipping frontend startup."
fi

echo "Dash services started."
