#!/bin/bash
set -e

# These come from the ENV in Dockerfile or ACI Runtime
echo "Configuring GitHub Runner for: $GITHUB_REPO_URL"

# 1. Configure the runner
# We use --unattended to avoid prompts and --replace to cleanup old sessions
./config.sh --url "$GITHUB_REPO_URL" \
            --token "$RUNNER_TOKEN" \
            --name "aci-runner-$(hostname)" \
            --work "_work" \
            --unattended \
            --replace

# 2. Start the runner
# Use 'exec' so that the runner process becomes PID 1 
# This ensures the container stays running and handles signals correctly
exec ./run.sh