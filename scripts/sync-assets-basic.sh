#!/bin/bash

# Script to sync assets
# Usage: ./sync-assets.sh

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Path to the canister IDs file relative to the script location
CANISTER_IDS_FILE="${SCRIPT_DIR}/../.dfx/local/canister_ids.json"

# Check if the file exists
if [ ! -f "$CANISTER_IDS_FILE" ]; then
    echo "Error: Canister IDs file not found at $CANISTER_IDS_FILE"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq to parse JSON."
    exit 1
fi

# Get the canister ID from the JSON file
CANISTER_ID=$(jq -r '.basic.local' "$CANISTER_IDS_FILE")

# Check if CANISTER_ID is empty or null
if [ -z "$CANISTER_ID" ] || [ "$CANISTER_ID" = "null" ]; then
    echo "Error: Could not find basic.local in canister_ids.json"
    exit 1
fi

# Run the sync command
icx-asset sync $CANISTER_ID examples/basic/assets

echo "Assets synced successfully for canister ID: $CANISTER_ID"