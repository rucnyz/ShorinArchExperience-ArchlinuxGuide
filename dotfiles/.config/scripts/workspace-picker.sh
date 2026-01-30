#!/bin/bash
# Edge Workspace Picker
# Read workspace list from Edge's WorkspacesCache and open with fuzzel

CACHE_FILE="$HOME/.config/microsoft-edge/Default/Workspaces/WorkspacesCache"

if [ ! -f "$CACHE_FILE" ]; then
    notify-send "Edge Workspace" "Workspace cache file not found"
    exit 1
fi

# Extract workspace names with tab count
workspaces=$(jq -r '.workspaces[] | "\(.name) (\(.count) tabs)"' "$CACHE_FILE")

# Build display list: create new option + workspaces
if [ -n "$workspaces" ]; then
    display_list=$(printf "[New Workspace...]\n%s" "$workspaces")
else
    display_list="[New Workspace...]"
fi

# Show with fuzzel
selected=$(echo "$display_list" | fuzzel --dmenu --cache="$HOME/.cache/fuzzel-edge-workspace" --prompt="Edge: ")

# Keep [New Workspace...] at top by setting highest frequency
FUZZEL_CACHE="$HOME/.cache/fuzzel-edge-workspace"
sed -i '/^\[New Workspace\.\.\.\]/d' "$FUZZEL_CACHE" 2>/dev/null
max_freq=$(awk -F'|' '{if($2>max)max=$2} END{print max+1}' "$FUZZEL_CACHE" 2>/dev/null)
echo "[New Workspace...]|${max_freq:-1}" >> "$FUZZEL_CACHE"

if [ -n "$selected" ]; then
    if [ "$selected" = "[New Workspace...]" ]; then
        # Open Edge without workspace (user can create new workspace manually)
        microsoft-edge-stable --force-device-scale-factor=1.1
    else
        # Extract workspace name (remove tab count)
        name=$(echo "$selected" | sed 's/ ([0-9]* tabs)$//')

        # Check if window with this workspace is already open (title == workspace name)
        window_id=$(niri msg -j windows | jq -r --arg name "$name" '.[] | select(.app_id == "microsoft-edge" and .title == $name) | .id' | head -1)

        if [ -n "$window_id" ]; then
            # Focus existing window
            niri msg action focus-window --id "$window_id"
        else
            # Find workspace ID and launch
            id=$(jq -r --arg name "$name" '.workspaces[] | select(.name == $name) | .id' "$CACHE_FILE")
            if [ -n "$id" ]; then
                microsoft-edge-stable --force-device-scale-factor=1.1 --launch-workspace="$id"
            fi
        fi
    fi
fi
