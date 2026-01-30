function pac --description "Fuzzy search and install packages with accurate installed status"
    # --- 1. 环境与颜色配置 ---
    set -lx LC_ALL C 
    
    set color_official  "\033[34m"   # 蓝色
    set color_aur       "\033[35m"   # 紫色
    set color_installed "\033[32m"   # 绿色
    set color_reset     "\033[0m"

    set aur_filter '^(mingw-|lib32-|cross-|.*-debug$)'
    set preview_cmd 'yay -Si {2}'

    # 创建两个临时文件
    set target_file (mktemp -t pac_fzf.XXXXXX)
    set installed_list (mktemp -t pac_installed.XXXXXX)

    # --- 2. 准备工作：获取已安装列表 ---
    # 这比依赖 yay/pacman 的输出文本更可靠。
    # -Q: 查询, -q: 仅输出包名
    pacman -Qq > $installed_list

    # --- 3. 定义 AWK 处理逻辑 ---
    # 这段 awk 脚本比较复杂，为了复用，我们定义成变量
    # 逻辑：
    # 1. 如果读取的是第一个文件 (FNR==NR)，它是 installed_list，将其存入 map。
    # 2. 如果读取的是后续流，它是 pacman/yay 输出。检查包名($2)是否在 map 中。
    set awk_cmd '
        # 阶段1：加载已安装列表到内存
        FNR==NR {
            installed[$1]=1; 
            next 
        }
        # 阶段2：处理包列表流
        {
            status=""
            # 直接查表，极快且准确
            if ($2 in installed) {
                status = ci " ✔ [已装]" r
            }
            # 格式化输出
            printf "%s%-10s%s %-30s %-20s %s\n", c, $1, r, $2, $3, status
        }
    '

    # --- 4. 生成数据流并交互 ---
    begin
        # A. 官方源
        # 注意：这里把 $installed_list 放在前面传给 awk
        pacman -Sl | awk -v c=$color_official -v ci=$color_installed -v r=$color_reset \
            "$awk_cmd" $installed_list -

        # B. AUR 源
        # 注意：同样把 $installed_list 作为第一个参数传给 awk，"-" 代表标准输入
        yay -Sl aur | grep -vE "$aur_filter" | awk -v c=$color_aur -v ci=$color_installed -v r=$color_reset \
            "$awk_cmd" $installed_list -
            
    end | \
    fzf --multi --ansi \
        --preview $preview_cmd --preview-window=right:50%:wrap \
        --height=95% --layout=reverse --border \
        --tiebreak=index \
        --nth=2 \
        --header 'Tab:多选 | Enter:安装 | Esc:退出' \
        --query "$argv" \
    > $target_file

    # --- 5. 执行安装 ---
    if test -s $target_file
        set packages (cat $target_file | awk '{print $2}')
        if test -n "$packages"
            echo -e "\n$color_installed>> 准备安装:$color_reset"
            echo $packages
            echo "----------------------------------------"
            yay -S $packages
        end
    end

    # 清理临时文件
    rm -f $target_file $installed_list
end

