#!/bin/bash
# PyCharm Project Picker
# Select a project from recent projects list and open with PyCharm

PYCHARM="/home/yuzhounie/.local/share/JetBrains/Toolbox/apps/pycharm/bin/pycharm"
RECENT_PROJECTS="$HOME/.config/JetBrains/PyCharm2025.3/options/recentProjects.xml"

# Extract project paths, replace $USER_HOME$ with actual path
projects=$(grep -oP 'entry key="\K[^"]+' "$RECENT_PROJECTS" | sed "s|\\\$USER_HOME\\\$|$HOME|g")

if [ -z "$projects" ]; then
    notify-send "PyCharm" "No recent projects found"
    exit 1
fi

# Create "name -> path" mapping, show only names
declare -A project_map
display_list=""
while IFS= read -r path; do
    name=$(basename "$path")
    project_map["$name"]="$path"
    display_list+="$name"$'\n'
done <<< "$projects"

# Add open folder option
display_list+="[Open Folder...]"$'\n'

# Show with fuzzel
selected_name=$(echo -n "$display_list" | fuzzel --dmenu --cache="$HOME/.cache/fuzzel-pycharm" --prompt="PyCharm: ")

# Clean special options from fuzzel cache
CACHE_FILE="$HOME/.cache/fuzzel-pycharm"
if [ -f "$CACHE_FILE" ]; then
    sed -i '/^\[Open Folder\.\.\.\]/d' "$CACHE_FILE"
fi

if [ -n "$selected_name" ]; then
    if [ "$selected_name" = "[Open Folder...]" ]; then
        folder=$(zenity --file-selection --directory --title="Select Project Folder" --filename="$HOME/yuzhou_data/PycharmProjects/")
        if [ -n "$folder" ]; then
            "$PYCHARM" "$folder"
        fi
    else
        # Check if window with this project is already open
        # PyCharm title format: "<project_name> [<path>] – <file>"
        window_id=$(niri msg -j windows | jq -r --arg name "$selected_name" '.[] | select(.app_id == "jetbrains-pycharm" and (.title | startswith($name + " ["))) | .id' | head -1)

        if [ -n "$window_id" ]; then
            # Focus existing window
            niri msg action focus-window --id "$window_id"
        else
            selected_path="${project_map[$selected_name]}"
            if [ -n "$selected_path" ]; then
                "$PYCHARM" "$selected_path"
            fi
        fi
    fi
fi
