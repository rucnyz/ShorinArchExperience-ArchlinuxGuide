#!/bin/bash
# 窗口焦点切换时显示 overlay 通知

# 存储窗口信息的关联数组
declare -A windows

niri msg --json event-stream | while read -r line; do
    # 更新窗口信息
    if echo "$line" | jq -e '.WindowsChanged' > /dev/null 2>&1; then
        while IFS= read -r win; do
            id=$(echo "$win" | jq -r '.id')
            title=$(echo "$win" | jq -r '.title')
            app_id=$(echo "$win" | jq -r '.app_id')
            windows[$id]="$app_id|$title"
        done < <(echo "$line" | jq -c '.WindowsChanged.windows[]')
    fi

    # 单个窗口更新
    if echo "$line" | jq -e '.WindowOpenedOrChanged' > /dev/null 2>&1; then
        id=$(echo "$line" | jq -r '.WindowOpenedOrChanged.window.id')
        title=$(echo "$line" | jq -r '.WindowOpenedOrChanged.window.title')
        app_id=$(echo "$line" | jq -r '.WindowOpenedOrChanged.window.app_id')
        windows[$id]="$app_id|$title"
    fi

    # 焦点变化时显示通知
    if echo "$line" | jq -e '.WindowFocusChanged' > /dev/null 2>&1; then
        id=$(echo "$line" | jq -r '.WindowFocusChanged.id')
        if [[ -n "${windows[$id]}" ]]; then
            IFS='|' read -r app_id title <<< "${windows[$id]}"
            # 截断过长的标题
            if [[ ${#title} -gt 50 ]]; then
                title="${title:0:47}..."
            fi
            # 发送短暂通知（1秒后消失）
            notify-send -t 1000 -h string:x-canonical-private-synchronous:focus-overlay "$app_id" "$title"
        fi
    fi
done
