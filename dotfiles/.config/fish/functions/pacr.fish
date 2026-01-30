# fzf卸载软件包
function pacr --description "Fuzzy find and remove packages (UI matched with pac)"
    # --- 配置区域 ---
    # 1. 定义颜色 (保持与 pac 一致)
    set color_official  "\033[34m"    
    set color_aur       "\033[35m"    
    set color_reset     "\033[0m"

    # --- 逻辑区域 ---
    # 预览命令：查询本地已安装详细信息 (-Qi)，目标是第2列(包名)
    set preview_cmd 'yay -Qi {2}'

    # 生成列表 -> 上色 -> fzf
    set packages (begin
        # 1. 官方源安装 (Native): 蓝色前缀 [local]
        pacman -Qn | awk -v c=$color_official -v r=$color_reset \
            '{printf "%s%-10s%s %-30s %s\n", c, "local", r, $1, $2}'

        # 2. AUR/外部源安装 (Foreign): 紫色前缀 [aur]
        pacman -Qm | awk -v c=$color_aur -v r=$color_reset \
            '{printf "%s%-10s%s %-30s %s\n", c, "aur", r, $1, $2}'
    end | \
    fzf --multi --ansi \
        --preview $preview_cmd --preview-window=right:60%:wrap \
        --height=95% --layout=reverse --border \
        --tiebreak=index \
        --nth=2 \
        --header 'Tab:多选 | Enter:卸载 | Esc:退出' \
        --query "$argv" | \
    awk '{print $2}') # 提取第2列纯净包名

    # --- 执行卸载 ---
    if test -n "$packages"
        echo "正在准备卸载: $packages"
        # -Rns: 递归删除配置文件和不再需要的依赖
        yay -Rns $packages
    end
end

