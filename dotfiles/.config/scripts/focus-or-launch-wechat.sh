#!/bin/bash
# Focus WeChat main window, or bring up from tray, or launch new instance

# Only match main window with title "微信"
WINDOW_ID=$(niri msg -j windows | jq -r '.[] | select(.app_id == "wechat" and .title == "微信") | .id' | head -1)

if [ -n "$WINDOW_ID" ]; then
    # Focus existing window
    niri msg action focus-window --id "$WINDOW_ID"
else
    # Check if WeChat process is running (in tray)
    WECHAT_PID=$(pgrep -x wechat | head -1)

    if [ -n "$WECHAT_PID" ]; then
        # Activate from tray via dbus
        gdbus call --session --dest "org.kde.StatusNotifierItem-${WECHAT_PID}-1" \
            --object-path /StatusNotifierItem \
            --method org.kde.StatusNotifierItem.Activate 0 0
    else
        # Start new instance
        wechat &
    fi
fi
