#!/bin/bash
# Thunderbird launcher with focus logic

# Check if thunderbird window is already open
window_id=$(niri msg -j windows | jq -r '.[] | select(.app_id == "thunderbird") | .id' | head -1)

if [ -n "$window_id" ]; then
    # Focus existing window
    niri msg action focus-window --id "$window_id"
else
    # Launch new instance
    GDK_DPI_SCALE=1.0 thunderbird
fi
