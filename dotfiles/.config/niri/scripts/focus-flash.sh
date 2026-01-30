#!/bin/bash
# 窗口焦点切换时边框闪烁（红色加粗）

COLORS_FILE="$HOME/.config/niri/colors.kdl"
FLASH_DURATION=0.2

# 闪烁配置（固定红色，加粗）
FLASH_CONTENT='layout{
    focus-ring{
        width 8
        active-color "#ff0000"
        urgent-color "#ff0000"
    }
}'

last_focus_id=""

niri msg --json event-stream | while read -r line; do
    if echo "$line" | jq -e '.WindowFocusChanged' > /dev/null 2>&1; then
        new_id=$(echo "$line" | jq -r '.WindowFocusChanged.id')

        if [[ "$new_id" != "$last_focus_id" && "$new_id" != "null" ]]; then
            last_focus_id="$new_id"

            # 保存当前配置
            original=$(cat "$COLORS_FILE")

            # 闪烁
            echo "$FLASH_CONTENT" > "$COLORS_FILE"
            niri msg action load-config-file > /dev/null 2>&1

            sleep $FLASH_DURATION

            # 恢复
            echo "$original" > "$COLORS_FILE"
            niri msg action load-config-file > /dev/null 2>&1
        fi
    fi
done
