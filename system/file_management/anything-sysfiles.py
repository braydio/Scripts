#!/usr/bin/env python3

import os
import subprocess
import datetime
import requests
import glob

###############################################################################
# CONFIGURATION (adjust these as needed)
###############################################################################

# Where to store collected system info on disk
SYSTEM_INFO_DIR = os.path.expanduser("~/Documents/SystemInfo")

# AnythingLLM server base URL (e.g., "http://localhost:3001/api")
ANYTHINGLLM_BASE_URL = "http://localhost:3001/api"

# Workspace ID (or slug) in AnythingLLM – you can find this in the UI or via API
WORKSPACE_ID = "your-workspace-id"

# Authorization token, API key, or set to None if no auth is required
# If using a Bearer token:
ANYTHINGLLM_AUTH_TOKEN = "YOUR_BEARER_TOKEN"  # or None if open

###############################################################################
# 1. GATHER SYSTEM INFO
###############################################################################

def gather_system_info(output_directory: str):
    """
    Collects various system details, writing each command's output 
    to separate text files in output_directory.
    """

    # Ensure output directory exists
    os.makedirs(output_directory, exist_ok=True)

    # Each command is a tuple: (filename, [command, args...])
    system_commands = [
        ("os_release.txt", ["cat", "/etc/os-release"]),
        ("cpu_info.txt", ["lscpu"]),
        ("mem_usage.txt", ["free", "-h"]),
        ("disk_usage.txt", ["df", "-h"]),
        ("running_processes.txt", ["ps", "aux"]),
        # Add or remove commands as needed...
    ]

    for filename, cmd in system_commands:
        output_path = os.path.join(output_directory, filename)
        try:
            # Run the command
            result = subprocess.run(cmd, capture_output=True, text=True, check=False)
            with open(output_path, "w") as f:
                f.write(result.stdout)
        except Exception as e:
            print(f"Warning: Failed to run {cmd}. Error: {e}")


###############################################################################
# 2. VERSIONING & GIT COMMIT
###############################################################################

def git_commit_snapshot(repo_directory: str):
    """
    Adds and commits all changes in repo_directory with an auto-generated
    commit message that includes timestamp and a version snippet.
    """

    # Build a commit message
    timestamp = datetime.datetime.now().isoformat(timespec='seconds')
    commit_message = f"AnythingLLM System Info Snapshot: {timestamp}"

    # Run git commands
    # 1) git add .
    subprocess.run(["git", "-C", repo_directory, "add", "."], check=False)
    # 2) git commit -m "..."
    subprocess.run(["git", "-C", repo_directory, "commit", "-m", commit_message], check=False)


###############################################################################
# 3. UPLOAD FILES TO ANYTHINGLLM
###############################################################################

def upload_file_to_anythingllm(file_path: str):
    """
    Sends an individual file to the AnythingLLM workspace via the Developer API.
    Typically, you'd use:
      POST /v1/workspaces/{workspaceId}/documents
    with multipart/form-data or JSON, depending on your config.
    """

    # Example endpoint: /v1/workspaces/<workspaceId>/documents
    endpoint = f"{ANYTHINGLLM_BASE_URL}/v1/workspaces/{WORKSPACE_ID}/documents"

    headers = {}
    if ANYTHINGLLM_AUTH_TOKEN:
        headers["Authorization"] = f"Bearer {ANYTHINGLLM_AUTH_TOKEN}"

    # The official docs often show a multipart/form upload:
    # "file" is the actual file, and possibly "documentName"/"documentDescription"
    # Adjust field names to match your server's expectations
    with open(file_path, "rb") as f:
        files = {
            "file": (os.path.basename(file_path), f, "text/plain"),
        }
        data = {
            "documentName": os.path.basename(file_path),
            "documentDescription": "System info snapshot file",
        }
        response = requests.post(endpoint, headers=headers, files=files, data=data)

    if not response.ok:
        print(f"Upload failed for {file_path}: {response.status_code} {response.text}")
    else:
        print(f"Uploaded {file_path} successfully. Server response: {response.json()}")


def upload_all_info_to_anythingllm(info_directory: str):
    """
    Iterates all files in info_directory and uploads them to AnythingLLM
    using the function above.
    """
    file_list = glob.glob(os.path.join(info_directory, "*"))
    for file_path in file_list:
        if os.path.isfile(file_path):
            upload_file_to_anythingllm(file_path)


###############################################################################
# MAIN SCRIPT ENTRY POINT
###############################################################################

def main():
    # 1) Gather system info
    gather_system_info(SYSTEM_INFO_DIR)

    # 2) Create a Git commit for versioning
    git_commit_snapshot(SYSTEM_INFO_DIR)

    # 3) Upload each system info file to AnythingLLM
    upload_all_info_to_anythingllm(SYSTEM_INFO_DIR)


if __name__ == "__main__":
    main()
