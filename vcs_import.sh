#!/bin/bash
# Fallback script for VCS import operations using Git Bash

# Ensure we're in the correct directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$SCRIPT_DIR"

echo "Importing submodules using VCS in Bash environment..."
vcs import < assets.repos

if [ $? -eq 0 ]; then
    echo "VCS import completed successfully."
    exit 0
else
    echo "Error during VCS import operation."
    exit 1
fi 