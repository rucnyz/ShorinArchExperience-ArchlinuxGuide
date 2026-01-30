#!/bin/bash

# ==============================================================================
# 1. 用户配置 (User Configuration)
# ==============================================================================

# --- 核心设置 ---
WALLPAPER_BACKEND="swww"
DAEMON_ARGS="-n overview"

# --- ImageMagick 参数 ---
IMG_BLUR_STRENGTH="0x15"
IMG_FILL_COLOR="black"
IMG_COLORIZE_STRENGTH="40%"

# --- 路径配置 ---
REAL_CACHE_BASE="$HOME/.cache/blur-wallpapers"
CACHE_SUBDIR_NAME="niri-overview-blur-dark"
LINK_NAME="cache-niri-overview-blur-dark"

# --- 自动预生成与清理配置 ---
AUTO_PREGEN="true"               # true/false：是否在后台进行维护
ORPHAN_CACHE_LIMIT=10            # 允许保留多少个“非重要壁纸”的缓存

# [关键配置] 重要壁纸目录
# 只有在这个目录根下的图片才会被加入白名单保护。
# 子目录里的图片不算“重要壁纸”。
WALL_DIR="$HOME/Pictures/Wallpapers"

# ==============================================================================
# 2. 依赖与输入检查
# ==============================================================================

DEPENDENCIES=("magick" "notify-send" "$WALLPAPER_BACKEND")

for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        notify-send -u critical "Blur Error" "缺少依赖: $cmd，请检查是否安装imagemagick"
        exit 1
    fi
done

INPUT_FILE="$1"

# 自动获取当前壁纸（若未指定）
if [ -z "$INPUT_FILE" ]; then
    if command -v "$WALLPAPER_BACKEND" &> /dev/null; then
        INPUT_FILE=$("$WALLPAPER_BACKEND" query 2>/dev/null | head -n1 | grep -oP 'image: \K.*')
    fi
fi

if [ -z "$INPUT_FILE" ] || [ ! -f "$INPUT_FILE" ]; then
    notify-send "Blur Error" "无法获取输入图片 (swww query 无返回)，请手动指定路径。"
    exit 1
fi

# 如果配置的 WALL_DIR 不存在，回退到当前图片所在目录
if [ -z "$WALL_DIR" ] || [ ! -d "$WALL_DIR" ]; then
    WALL_DIR=$(dirname "$INPUT_FILE")
fi

# ==============================================================================
# 3. 路径与链接逻辑
# ==============================================================================

# A. 准备真实缓存目录
REAL_CACHE_DIR="$REAL_CACHE_BASE/$CACHE_SUBDIR_NAME"
mkdir -p "$REAL_CACHE_DIR"

# B. 准备软链接
WALLPAPER_DIR=$(dirname "$INPUT_FILE")
SYMLINK_PATH="$WALLPAPER_DIR/$LINK_NAME"

if [ ! -L "$SYMLINK_PATH" ] || [ "$(readlink -f "$SYMLINK_PATH")" != "$REAL_CACHE_DIR" ]; then
    if [ -d "$SYMLINK_PATH" ] && [ ! -L "$SYMLINK_PATH" ]; then
        : 
    else
        ln -sfn "$REAL_CACHE_DIR" "$SYMLINK_PATH"
    fi
fi

# C. 定义文件名和前缀
FILENAME=$(basename "$INPUT_FILE")
SAFE_OPACITY="${IMG_COLORIZE_STRENGTH%\%}"
SAFE_COLOR="${IMG_FILL_COLOR#\#}"
PARAM_PREFIX="blur-${IMG_BLUR_STRENGTH}-${SAFE_COLOR}-${SAFE_OPACITY}-"

BLUR_FILENAME="${PARAM_PREFIX}${FILENAME}"
FINAL_IMG_PATH="$REAL_CACHE_DIR/$BLUR_FILENAME"

# ==============================================================================
# 4. 后台维护功能 (清理 + 预生成)
# ==============================================================================
log() { echo "[$(date '+%H:%M:%S')] $*"; }

target_for() {
    local img="$1"
    local base="${img##*/}"
    echo "$REAL_CACHE_DIR/${PARAM_PREFIX}${base}"
}

run_maintenance_in_background() {
    local current_img="$1"
    local current_cache_target="$2"
    
    (
        # === A. 清理逻辑 (Smart Clean) ===
        # 1. 建立白名单：只扫描 WALL_DIR 根目录 (-maxdepth 1)
        # 子目录里的图片不会被加入白名单 -> 它们的缓存会被视为“孤儿” -> 最终被清理
        declare -A active_wallpapers
        local whitelist_count=0
        
        while IFS= read -r -d '' file; do
            local basename="${file##*/}"
            active_wallpapers["$basename"]=1
            whitelist_count=$((whitelist_count + 1))
        done < <(find -L "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0)

        # 2. 扫描缓存，找出孤儿
        local orphan_list=$(mktemp)
        local orphan_count=0
        
        # 仅扫描当前参数前缀的缓存文件
        while IFS= read -r -d '' cache_file; do
            local cache_name="${cache_file##*/}"
            local original_name="${cache_name#${PARAM_PREFIX}}"
            
            # 逻辑判断：
            # 1. 如果源图不在白名单里（比如它是子目录里的图，或者是已删除的图）
            if [[ -z "${active_wallpapers[$original_name]}" ]]; then
                # 2. 绝对保护：哪怕它不在白名单，只要是当前正在用的，就坚决不删
                if [[ "$cache_file" != "$current_cache_target" ]]; then
                    echo "$cache_file" >> "$orphan_list"
                    orphan_count=$((orphan_count + 1))
                fi
            fi
        done < <(find "$REAL_CACHE_DIR" -maxdepth 1 -name "${PARAM_PREFIX}*" -print0)

        # 3. 执行删除 (只删除超量的孤儿)
        if [[ "$orphan_count" -gt "$ORPHAN_CACHE_LIMIT" ]]; then
            local delete_count=$((orphan_count - ORPHAN_CACHE_LIMIT))
            # 按访问时间排序删除最旧的
            xargs -a "$orphan_list" ls -1tu | tail -n "$delete_count" | while read -r dead_file; do
                rm -f "$dead_file"
            done
        fi
        rm -f "$orphan_list"

        # === B. 预生成逻辑 (Pre-Gen) ===
        # 同样只为白名单里的图片（根目录图片）预生成缓存
        local total=0
        while IFS= read -r -d '' img; do
            [[ -n "$current_img" && "$img" == "$current_img" ]] && continue
            
            total=$((total + 1))
            local tgt
            tgt=$(target_for "$img")

            if [[ -f "$tgt" ]]; then
                continue
            fi

            if [[ -n "$IMG_FILL_COLOR" && -n "$IMG_COLORIZE_STRENGTH" ]]; then
                magick "$img" -blur "$IMG_BLUR_STRENGTH" -fill "$IMG_FILL_COLOR" -colorize "$IMG_COLORIZE_STRENGTH" "$tgt"
            else
                magick "$img" -blur "$IMG_BLUR_STRENGTH" "$tgt"
            fi
        done < <(find -L "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' -o -iname '*.webp' \) -print0)
    ) & 
}

# ==============================================================================
# 5. 生成与应用函数
# ==============================================================================

apply_wallpaper() {
    local img_path="$1"
    
    # 只要命中了缓存，更新访问时间
    touch -a "$img_path"

    "$WALLPAPER_BACKEND" img $DAEMON_ARGS "$img_path" \
        --transition-type fade \
        --transition-duration 0.5 \
        & 
}

# ==============================================================================
# 6. 主逻辑
# ==============================================================================

# 若缓存命中
if [ -f "$FINAL_IMG_PATH" ]; then
    apply_wallpaper "$FINAL_IMG_PATH"

    if [[ "$AUTO_PREGEN" == "true" ]]; then
        run_maintenance_in_background "$INPUT_FILE" "$FINAL_IMG_PATH"
    fi
    exit 0
fi

# 若无缓存，生成当前壁纸
if [[ -n "$IMG_FILL_COLOR" && -n "$IMG_COLORIZE_STRENGTH" ]]; then
    magick "$INPUT_FILE" -blur "$IMG_BLUR_STRENGTH" -fill "$IMG_FILL_COLOR" -colorize "$IMG_COLORIZE_STRENGTH" "$FINAL_IMG_PATH"
else
    magick "$INPUT_FILE" -blur "$IMG_BLUR_STRENGTH" "$FINAL_IMG_PATH"
fi

if [ $? -ne 0 ]; then
    notify-send "Blur Error" "ImageMagick 生成失败"
    exit 1
fi

# 应用壁纸
apply_wallpaper "$FINAL_IMG_PATH"

# 后台运行维护
if [[ "$AUTO_PREGEN" == "true" ]]; then
    run_maintenance_in_background "$INPUT_FILE" "$FINAL_IMG_PATH"
fi

exit 0