#!/bin/bash
# 双显示器 Workspace 切换同步脚本
# 当一个显示器切换 workspace 时，另一个显示器也切换到对应 idx 的 workspace

MONITOR_1="HDMI-A-2"  # 主屏
MONITOR_2="HDMI-A-1"  # 副屏
COOLDOWN_MS=300  # 同步后冷却时间（毫秒）
LAST_SYNC_TIME=0

cleanup() {
    exit 0
}
trap cleanup SIGINT SIGTERM

echo "=========================================="
echo "[启动] Workspace 切换同步脚本"
echo "[主屏] $MONITOR_1"
echo "[副屏] $MONITOR_2"
echo "=========================================="

# 获取当前毫秒时间戳
get_time_ms() {
    echo $(($(date +%s%N) / 1000000))
}

WORKSPACES_CACHE=$(niri msg -j workspaces)

niri msg -j event-stream | while read -r line; do
    # 更新 workspace 缓存
    if echo "$line" | jq -e '.WorkspacesChanged' > /dev/null 2>&1; then
        WORKSPACES_CACHE=$(echo "$line" | jq -r '.WorkspacesChanged.workspaces')
        continue
    fi

    # 只处理 WorkspaceActivated
    echo "$line" | jq -e '.WorkspaceActivated' > /dev/null 2>&1 || continue

    # 检查冷却时间
    NOW=$(get_time_ms)
    # 从文件读取上次同步时间（subshell 变量问题）
    LAST_SYNC_TIME=$(cat /tmp/niri-sync-time 2>/dev/null || echo 0)
    ELAPSED=$((NOW - LAST_SYNC_TIME))

    if [[ $ELAPSED -lt $COOLDOWN_MS ]]; then
        continue
    fi

    WS_ID=$(echo "$line" | jq -r '.WorkspaceActivated.id')
    FOCUSED=$(echo "$line" | jq -r '.WorkspaceActivated.focused')
    [[ "$FOCUSED" != "true" ]] && continue

    # 获取当前 workspace 的 output 和 idx
    WS_INFO=$(echo "$WORKSPACES_CACHE" | jq -r ".[] | select(.id == $WS_ID)")
    WS_OUTPUT=$(echo "$WS_INFO" | jq -r '.output')
    WS_IDX=$(echo "$WS_INFO" | jq -r '.idx')

    [[ -z "$WS_IDX" || "$WS_IDX" == "null" ]] && continue

    # 确定目标显示器
    if [[ "$WS_OUTPUT" == "$MONITOR_1" ]]; then
        TARGET="$MONITOR_2"
    elif [[ "$WS_OUTPUT" == "$MONITOR_2" ]]; then
        TARGET="$MONITOR_1"
    else
        continue
    fi

    # 检查目标 workspace 是否有名字
    TARGET_WS_NAME=$(echo "$WORKSPACES_CACHE" | jq -r ".[] | select(.output == \"$TARGET\" and .idx == $WS_IDX) | .name // empty")

    echo "[同步] idx $WS_IDX: $WS_OUTPUT -> $TARGET"

    # 记录同步时间
    get_time_ms > /tmp/niri-sync-time

    niri msg action focus-monitor "$TARGET"
    niri msg action focus-workspace "$WS_IDX"

    # 如果目标 workspace 没有名字，设置为 "ws N"
    if [[ -z "$TARGET_WS_NAME" || "$TARGET_WS_NAME" == "null" ]]; then
        niri msg action set-workspace-name "ws $WS_IDX"
        echo "  [命名] $TARGET workspace $WS_IDX -> 'ws $WS_IDX'"
    fi

    niri msg action focus-monitor "$WS_OUTPUT"

    # 更新同步时间（同步完成后）
    get_time_ms > /tmp/niri-sync-time
done
