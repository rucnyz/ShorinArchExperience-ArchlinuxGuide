#!/bin/bash

# --- 参数定义 ---
WALLPAPER="$1"
CACHE_DIR="$HOME/.cache/matugen-strategy"
TYPE_FILE="$CACHE_DIR/type"
MODE_FILE="$CACHE_DIR/mode"
WAYPAPER_CONFIG="$HOME/.config/waypaper/config.ini"

# --- 1. 获取壁纸路径 ---
if [ -z "$WALLPAPER" ]; then
    # 优先 swww
    if command -v swww &>/dev/null && pgrep -x "swww-daemon" >/dev/null; then
         DETECTED_WALL=$(swww query | head -n 1 | awk -F ': ' '{print $2}' | awk '{print $1}')
         if [ -n "$DETECTED_WALL" ] && [ -f "$DETECTED_WALL" ]; then
            WALLPAPER="$DETECTED_WALL"
         fi
    fi
    # 备选 Waypaper
    if [ -z "$WALLPAPER" ] && [ -f "$WAYPAPER_CONFIG" ]; then
        WP_PATH=$(sed -n 's/^wallpaper[[:space:]]*=[[:space:]]*//p' "$WAYPAPER_CONFIG")
        WP_PATH="${WP_PATH/#\~/$HOME}"
        if [ -n "$WP_PATH" ] && [ -f "$WP_PATH" ]; then
            WALLPAPER="$WP_PATH"
        fi
    fi
fi

if [ -z "$WALLPAPER" ] || [ ! -f "$WALLPAPER" ]; then
    notify-send "Matugen Error" "无法找到壁纸路径。"
    exit 1
fi
ln -sf "$WALLPAPER" "$HOME/.cache/.current_wallpaper"
# --- 2. 读取策略 (Type) ---
if [ -f "$TYPE_FILE" ]; then
    STRATEGY=$(cat "$TYPE_FILE")
else
    STRATEGY="scheme-tonal-spot"
fi

# --- 3. 读取模式 (Mode) ---
if [ -f "$MODE_FILE" ]; then
    MODE=$(cat "$MODE_FILE")
else
    MODE="dark"
fi

# --- 4. [核心修复] 脏更新 (Force Toggle) ---
# 强制先切换到“反向模式”，再切换回“目标模式”
# 确保 D-Bus 发出 'changed' 信号，强制 Nautilus 等应用重绘



# --- 5. 执行 Matugen ---
matugen image "$WALLPAPER" -t "$STRATEGY" -m "$MODE"

if [ "$MODE" == "light" ]; then
    # === 目标：亮色 ===

    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-light"
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3"
else
    # === 目标：暗色 ===
    gsettings set org.gnome.desktop.interface color-scheme "prefer-light"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    gsettings set org.gnome.desktop.interface gtk-theme "adw-gtk3-dark"
fi
