#!/bin/bash
# SSH Host Picker
# Read hosts from ~/.ssh/config and connect via kitty + autossh

SSH_CONFIG="$HOME/.ssh/config"

if [ ! -f "$SSH_CONFIG" ]; then
    notify-send "SSH Picker" "SSH config not found"
    exit 1
fi

# Extract Host names (exclude wildcards like *)
hosts=$(grep -E "^Host " "$SSH_CONFIG" | awk '{print $2}' | grep -v '\*')

if [ -z "$hosts" ]; then
    notify-send "SSH Picker" "No hosts found"
    exit 1
fi

# Show with fuzzel
selected=$(echo "$hosts" | fuzzel --dmenu --cache="$HOME/.cache/fuzzel-ssh" --prompt="SSH: ")

if [ -n "$selected" ]; then
    # Launch kitty with autossh, open tmux choose-tree
    kitty -e sh -c "autossh -M 0 -o 'ServerAliveInterval 10' -o 'ServerAliveCountMax 3' $selected -t 'tmux -u new-session -A \\; choose-tree -s'"
fi
