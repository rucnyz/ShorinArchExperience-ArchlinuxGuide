if status is-interactive
    # Commands to run in interactive sessions can go here
end
set fish_greeting ""

starship init fish | source
zoxide init fish --cmd cd | source

function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	yazi $argv --cwd-file="$tmp"
	if read -z cwd < "$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
		builtin cd -- "$cwd"
	end
	rm -f -- "$tmp"
end

function ls
	command eza $argv
end


thefuck --alias | source
# fa运行fastfetch
abbr fa fastfetch
# f运行带二次元美少女的fastfetch
function f 
    command bash $HOME/.config/scripts/fastfetch-random-wife.sh
   end
function fnsfw
    command env NSFW=1 bash $HOME/.config/scripts/fastfetch-random-wife.sh
   end
abbr reboot 'systemctl reboot'
function 滚
	sysup 
end
function 更新
	sysup 
end
function 清理
	command yay -Scc 
end
function 安装
	command yay -S $argv
end
function 卸载
	command yay -Rns $argv
end
function clean
	command yay -Scc 
end
function install
	command yay -S $argv
end
function remove 
	command yay -Rns $argv
end
