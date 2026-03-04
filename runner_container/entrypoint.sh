#!/bin/bash
# Required Env Vars: REPO_URL, RUNNER_TOKEN, RUNNER_NAME, RUNNER_LABELS
# Parameters
GITHUB_REPO_URL=$1
RUNNER_TOKEN=$
BASE_RUNNER_NAME=$3   # The base name (e.g., "my-runner")
RUNNER_LABELS=$4
ADMIN_USERNAME=$5

# Registration
./config.sh --url ${REPO_URL} \
            --token ${RUNNER_TOKEN} \
            --name ${RUNNER_NAME:-aci-runner} \
            --labels ${RUNNER_LABELS:-aci-default} \
            --unattended --replace --ephemeral

# Start the runner
./run.sh