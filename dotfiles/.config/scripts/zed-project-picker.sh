#!/bin/bash
# Zed Project Picker
# Read project list from Zed's SQLite database and open with fuzzel

ZED_DB="$HOME/.local/share/zed/db/0-stable/db.sqlite"

if [ ! -f "$ZED_DB" ]; then
    notify-send "Zed" "Database not found"
    exit 1
fi

# Get project paths from database
paths=$(sqlite3 "$ZED_DB" "SELECT paths FROM workspaces WHERE paths IS NOT NULL AND paths <> ''")

# Build display list: project names + open folder option
display_list=""
declare -A project_map

while IFS= read -r path; do
    if [ -n "$path" ]; then
        name=$(basename "$path")
        project_map["$name"]="$path"
        display_list+="$name"$'\n'
    fi
done <<< "$paths"

display_list+="[Open Folder...]"

# Show with fuzzel
selected=$(echo -n "$display_list" | fuzzel --dmenu --cache="$HOME/.cache/fuzzel-zed" --prompt="Zed: ")

# Clean special options from fuzzel cache
CACHE_FILE="$HOME/.cache/fuzzel-zed"
if [ -f "$CACHE_FILE" ]; then
    sed -i '/^\[Open Folder\.\.\.\]/d' "$CACHE_FILE"
fi

if [ -n "$selected" ]; then
    if [ "$selected" = "[Open Folder...]" ]; then
        folder=$(zenity --file-selection --directory --title="Select Folder")
        if [ -n "$folder" ]; then
            zed "$folder"
        fi
    else
        # Check if window with this project is already open
        # Zed title format: "<project_name> — <filename>"
        window_id=$(niri msg -j windows | jq -r --arg name "$selected" '.[] | select(.app_id == "dev.zed.Zed" and (.title | startswith($name + " — "))) | .id' | head -1)

        if [ -n "$window_id" ]; then
            niri msg action focus-window --id "$window_id"
        else
            path="${project_map[$selected]}"
            if [ -n "$path" ]; then
                zed "$path"
            fi
        fi
    fi
fi
