#!/bin/bash
# Cursor Project Picker
# Read recently opened projects from Cursor's state database

STATE_DB="$HOME/.config/Cursor/User/globalStorage/state.vscdb"

if [ ! -f "$STATE_DB" ]; then
    notify-send "Cursor" "Database not found"
    exit 1
fi

# Extract recently opened paths from database
# Includes both workspaces (.code-workspace) and folders
entries=$(sqlite3 "$STATE_DB" "SELECT value FROM ItemTable WHERE key='history.recentlyOpenedPathsList'" 2>/dev/null)

if [ -z "$entries" ]; then
    notify-send "Cursor" "No recent projects found"
    exit 1
fi

# Parse entries: workspace configPath or folderUri
declare -A project_map
display_list=""

# Process workspaces (*.code-workspace files)
while IFS= read -r path; do
    if [ -n "$path" ]; then
        path=$(echo "$path" | sed 's|^file://||')
        name=$(basename "$path" .code-workspace)
        project_map["$name"]="$path"
        display_list+="$name"$'\n'
    fi
done <<< "$(echo "$entries" | jq -r '.entries[]? | .workspace?.configPath // empty')"

# Process folders
while IFS= read -r path; do
    if [ -n "$path" ]; then
        path=$(echo "$path" | sed 's|^file://||')
        name=$(basename "$path")
        # Avoid duplicates (folder might have same name as workspace)
        if [ -z "${project_map[$name]}" ]; then
            project_map["$name"]="$path"
            display_list+="$name"$'\n'
        fi
    fi
done <<< "$(echo "$entries" | jq -r '.entries[]? | .folderUri // empty')"

# Add options
display_list+="[Open Folder...]"$'\n'
display_list+="[Open File...]"

# Show with fuzzel
selected=$(echo -n "$display_list" | fuzzel --dmenu --cache="$HOME/.cache/fuzzel-cursor" --prompt="Cursor: ")

# Clean special options from fuzzel cache
CACHE_FILE="$HOME/.cache/fuzzel-cursor"
if [ -f "$CACHE_FILE" ]; then
    sed -i '/^\[Open Folder\.\.\.\]/d; /^\[Open File\.\.\.\]/d' "$CACHE_FILE"
fi

if [ -n "$selected" ]; then
    if [ "$selected" = "[Open Folder...]" ]; then
        folder=$(zenity --file-selection --directory --title="Select Folder" --filename="$HOME/yuzhou_data/PycharmProjects/")
        if [ -n "$folder" ]; then
            cursor --new-window "$folder"
        fi
    elif [ "$selected" = "[Open File...]" ]; then
        file=$(zenity --file-selection --title="Select File or Workspace" --file-filter="All Files | *" --file-filter="Workspace | *.code-workspace")
        if [ -n "$file" ]; then
            cursor --new-window "$file"
        fi
    else
        # Check if window with this project is already open
        window_id=$(niri msg -j windows | jq -r --arg name "$selected" '.[] | select(.app_id == "cursor" and (.title | contains($name))) | .id' | head -1)

        if [ -n "$window_id" ]; then
            niri msg action focus-window --id "$window_id"
        else
            path="${project_map[$selected]}"
            if [ -n "$path" ]; then
                cursor --new-window "$path"
            else
                cursor --new-window
            fi
        fi
    fi
fi
