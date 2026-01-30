#!/usr/bin/env bash

# 20分钟熄屏，60分钟挂起
exec swayidle -w \
timeout 1200 'niri msg action power-off-monitors' \
resume       'niri msg action power-on-monitors' \
timeout 3600 'systemctl suspend'
