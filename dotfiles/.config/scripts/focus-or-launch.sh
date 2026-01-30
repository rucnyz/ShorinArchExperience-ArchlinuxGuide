#!/bin/bash
# Focus existing window or launch new instance
# Usage: focus-or-launch.sh <app_id> <launch_command>

APP_ID="$1"
shift
LAUNCH_CMD="$@"

# Find window with matching app_id
WINDOW_ID=$(niri msg -j windows | jq -r ".[] | select(.app_id == \"$APP_ID\") | .id" | head -1)

if [ -n "$WINDOW_ID" ]; then
    # Focus existing window
    niri msg action focus-window --id "$WINDOW_ID"
else
    # Launch new instance
    $LAUNCH_CMD &
fi
