#!/bin/bash

bar="▁▂▃▄▅▆▇█"
config_file="/tmp/waybar_cava_config"

# 当脚本退出(EXIT)或被中断时，自动杀掉当前脚本的子进程(cava)
trap "pkill -P $$" EXIT

# --- 2. 生成配置 ---
echo "
[general]
framerate = 24
sleep_timer = 1   
bars = 8

[input]
method = pulse

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
" > "$config_file"

# --- 3. 构建字典 ---
dict="s/;//g;"
i=0
while [ $i -lt ${#bar} ]
do
    dict="${dict}s/$i/${bar:$i:1}/g;"
    i=$((i=i+1))
done

# --- 4. 运行 ---
cava -p "$config_file" | sed -u "$dict"
