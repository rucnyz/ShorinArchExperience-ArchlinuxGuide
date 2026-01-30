eval "$(starship init zsh)"
#语法检查和高亮
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
#开启tab上下左右选择补全
zstyle ':completion:*' menu select
autoload -Uz compinit
compinit

alias icat="kitty +kitten icat"

# 设置历史记录文件的路径
HISTFILE=~/.zsh_history

# 设置在会话（内存）中和历史文件中保存的条数，建议设置得大一些
HISTSIZE=1000
SAVEHIST=1000

# 忽略重复的命令，连续输入多次的相同命令只记一次
setopt HIST_IGNORE_DUPS

# 忽略以空格开头的命令（用于临时执行一些你不想保存的敏感命令）
setopt HIST_IGNORE_SPACE

# 每条命令执行后立即追加到历史文件（实时同步）
setopt INC_APPEND_HISTORY

# 让新的历史记录追加到文件，而不是覆盖
setopt APPEND_HISTORY
# 在历史记录中记录命令的执行开始时间和持续时间
setopt EXTENDED_HISTORY
eval "$(zoxide init zsh)"

# f: fastfetch with random waifu
f() { bash "$HOME/.config/scripts/fastfetch-random-wife.sh"; }

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
	rm -f -- "$tmp"
}

export PATH="$HOME/.local/bin:$PATH"

# FZF
export FZF_DEFAULT_COMMAND="fd --type f --hidden --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type d --hidden --exclude .git"
export FZF_DEFAULT_OPTS="--preview '
if file --mime-type {} | grep -q image; then
  kitty +kitten icat --clear --transfer-mode=memory --stdin=no --place=40x20@0x0 {} 2>/dev/null
else
  bat --color=always {} 2>/dev/null || cat {}
fi'"
export FZF_CTRL_T_OPTS="--preview '
if file --mime-type {} | grep -q image; then
  kitty +kitten icat --clear --transfer-mode=memory --stdin=no --place=40x20@0x0 {} 2>/dev/null
else
  bat --color=always {} 2>/dev/null || cat {}
fi'"
export FZF_ALT_C_OPTS="--preview 'tree -C {} | head -50'"
export FZF_CTRL_R_OPTS="--wrap --preview ''"
source /usr/share/fzf/key-bindings.zsh
source /usr/share/fzf/completion.zsh

# Ctrl+R 搜索前先刷新历史（跨终端同步）
function fzf-history-widget-refreshed() {
  fc -R
  fzf-history-widget
}
zle -N fzf-history-widget-refreshed
bindkey '^R' fzf-history-widget-refreshed

# Alias
alias c='SUPERMEMORY_CC_API_KEY=sm_C2zFr9X5K8XFUJfqoCp65b_syklaixUdWVnsXRQWkSNveYCYbRzIgiwdrvehYVtOkAhiYkUpxsTQJRqDVUVgfJv claude --dangerously-skip-permissions'
alias o='opencode'
alias m='micro'
alias ls='eza --group-directories-first --icons=auto'
alias ll='eza -alh --group-directories-first --git --icons=auto'
alias la='eza -A --group-directories-first --icons=auto'
alias lt='eza --tree --level=2 --icons=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias lg='lazygit'
alias cpa='pwd | wl-copy'
function cf { [[ -f "$1" ]] && wl-copy < "$1" || echo "用法: cf <文件>"; }

# direnv
eval "$(direnv hook zsh)"

# direnv 快捷配置
# me: 创建/编辑 .envrc，加载 .env
alias me='[[ -f .envrc ]] || echo "dotenv" > .envrc; micro .envrc && direnv allow'
# mev: 配置 Python venv
alias mev='[[ -f .envrc ]] || echo -e "dotenv\nexport VIRTUAL_ENV_DISABLE_PROMPT=1\nsource .venv/bin/activate" > .envrc; micro .envrc && direnv allow'
# mec: 配置 conda 环境（默认 llm，可传参 mec myenv）
function mec { [[ -f .envrc ]] || echo -e "dotenv\neval \"\$(conda shell.zsh hook)\" && conda activate ${1:-llm}" > .envrc; micro .envrc && direnv allow; }

# 设置编辑器（Alt+E 会用这个）
export EDITOR=micro

# Alt+E 用编辑器编辑当前命令
autoload -U edit-command-line
zle -N edit-command-line
bindkey '\ee' edit-command-line

# Alt+Z 撤销，Alt+Shift+Z 重做
bindkey '\ez' undo
bindkey '\eZ' redo

# Alt+A 返回上一个目录
function _cd_back { cd - > /dev/null && zle reset-prompt; }
zle -N _cd_back
bindkey '\ea' _cd_back

# 禁用终端流控制，让 Ctrl+S/Ctrl+Q 可用
stty -ixon
# Ctrl+S 清屏
bindkey '^S' clear-screen

# Ctrl+Q 复制当前命令到剪贴板
function copy-line-to-clipboard() {
  echo -n "$BUFFER" | wl-copy
}
zle -N copy-line-to-clipboard
bindkey '^Q' copy-line-to-clipboard

# Home/End keys (multiple sequences for different terminals)
bindkey '^[[H' beginning-of-line    # xterm/kitty
bindkey '^[[F' end-of-line          # xterm/kitty
bindkey '^[[1~' beginning-of-line   # tmux/screen
bindkey '^[[4~' end-of-line         # tmux/screen
bindkey '^[OH' beginning-of-line    # some terminals
bindkey '^[OF' end-of-line          # some terminals
# Ctrl+Left/Right 按单词移动
bindkey '^[[1;5D' backward-word
bindkey '^[[1;5C' forward-word

# Double Esc to add sudo
sudo-command-line() {
    [[ -z $BUFFER ]] && BUFFER=$(fc -ln -1)
    if [[ $BUFFER == sudo\ * ]]; then
        BUFFER="${BUFFER#sudo }"
    else
        BUFFER="sudo $BUFFER"
    fi
    CURSOR=${#BUFFER}
}
zle -N sudo-command-line
bindkey '\e\e' sudo-command-line

# SSH Agent 自动启动
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
fi

# bun completions
[ -s "/home/yuzhounie/.bun/_bun" ] && source "/home/yuzhounie/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# System update function (ported from fish)
function sysup() {
    local update_cmd=""
    if command -v yay &>/dev/null; then update_cmd="yay"
    elif command -v paru &>/dev/null; then update_cmd="paru"
    else echo -e "\n\033[1;31m!!! Error: No AUR helper found (yay/paru) !!!\033[0m"; return 1; fi

    local news_url="https://archlinux.org/feeds/news/"
    local count_limit=${1:-15}

    echo -e "\n\033[1;36m==> Preparing to update system with $update_cmd...\033[0m"
    echo -e "\033[1;36m==> Fetching latest Arch Linux news...\033[0m"

    if curl -sS -L --connect-timeout 15 -A "Mozilla/5.0" "$news_url" | python -c "
import sys, xml.etree.ElementTree as ET
try:
    limit = int(sys.argv[1])
    raw_data = sys.stdin.read()
    if not raw_data.strip(): sys.exit(1)
    root = ET.fromstring(raw_data)
    items = root.findall('./channel/item')[:limit]
    print(f'\n\033[1;33m>>> Recent {len(items)} Arch Linux news items:\033[0m\n')
    for item in items:
        title, pub_date = item.find('title').text, item.find('pubDate').text
        check_text = title.lower()
        if any(x in check_text for x in ['intervention', 'manual']):
            print(f'\033[1;31m[{pub_date[:16]}] !!! {title}\033[0m')
        else:
            print(f'\033[1;32m[{pub_date[:16]}] {title}\033[0m')
except: sys.exit(1)
" "$count_limit"; then
        echo ""
        read "confirm?Read above. Proceed with $update_cmd? [Y/n] "
        case "$confirm" in
            [Nn]*) echo -e "\n\033[1;33m==> Update cancelled.\033[0m" ;;
            *)
                echo -e "\n\033[1;34m==> [Step 1/3] Syncing DB & Updating keyrings...\033[0m"
                local -a keyring_targets=(archlinux-keyring)
                pacman -Qq archlinuxcn-keyring &>/dev/null && keyring_targets+=(archlinuxcn-keyring)
                sudo pacman -Sy --needed --noconfirm "${keyring_targets[@]}"

                echo -e "\n\033[1;36m==> [Step 2/3] Upgrading system...\033[0m"
                $update_cmd -Su

                if command -v flatpak &>/dev/null; then
                    echo -e "\n\033[1;35m==> [Step 3/3] Checking Flatpak updates...\033[0m"
                    flatpak update
                fi
                ;;
        esac
    else
        echo -e "\n\033[1;31m!!! WARNING: Failed to fetch news !!!\033[0m"
        read "force?Force update ignoring news? [y/N] "
        case "$force" in
            [Yy]*)
                local -a keyring_targets=(archlinux-keyring)
                pacman -Qq archlinuxcn-keyring &>/dev/null && keyring_targets+=(archlinuxcn-keyring)
                sudo pacman -Sy --needed --noconfirm "${keyring_targets[@]}"
                $update_cmd -Su
                command -v flatpak &>/dev/null && flatpak update
                ;;
            *) echo -e "\n\033[1;33m==> Safe exit.\033[0m" ;;
        esac
    fi
}
alias 滚='sysup'
alias 更新='sysup'

# SSH + tmux: 连接服务器并进入 tmux 选择界面（使用 autossh 自动重连）
st() {
    autossh -M 0 -o "ServerAliveInterval 10" -o "ServerAliveCountMax 3" -t "$1" "tmux -u new-session -A \; choose-tree -s"
}

