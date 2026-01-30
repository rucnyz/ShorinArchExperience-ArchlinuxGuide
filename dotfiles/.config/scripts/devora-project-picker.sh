#!/bin/bash
# Devora Project Picker
# Read project list from Devora config and open with fuzzel

DEVORA_DIR="$HOME/yuzhou_data/config/devora"
METADATA_FILE="$DEVORA_DIR/metadata.json"

if [ ! -f "$METADATA_FILE" ]; then
    notify-send "Devora" "Config not found"
    exit 1
fi

# Get project names directly from metadata.json (new format: .projects[].name)
projects=$(jq -r '.projects[].name' "$METADATA_FILE" 2>/dev/null)

if [ -z "$projects" ]; then
    notify-send "Devora" "No projects found"
    exit 1
fi

# Show with fuzzel
selected=$(echo -n "$projects" | fuzzel --dmenu --cache="$HOME/.cache/fuzzel-devora" --prompt="Devora: ")

if [ -n "$selected" ]; then
    # Check if window with this project is already open
    # Devora title format: "Devora - <project_name>"
    window_id=$(niri msg -j windows | jq -r --arg name "$selected" '.[] | select(.app_id == "devora" and .title == "Devora - " + $name) | .id' | head -1)

    if [ -n "$window_id" ]; then
        # Focus existing window
        niri msg action focus-window --id "$window_id"
    else
        # Launch with project
        devora --project "$selected"
    fi
fi
