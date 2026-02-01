set PATH /home/linuxbrew/.linuxbrew/bin $PATH

set PATH $HOME/.local/bin $PATH

# fzf
set -x FZF_DEFAULT_COMMAND "rg --files --hidden --follow --glob '!.git'"
set -x FZF_DEFAULT_OPTS "--height 40% --reverse"

# aliases
alias vim=nvim

# for some reason this is necessary to make tmux true color work inside of docker.
alias tmux="TERM=xterm-256color command tmux"

alias cat=bat

# direnv hooks
 direnv hook fish | source

# starship
starship init fish | source

# try to source a machine specific config
if test -e ~/.local.fish
  source ~/.local.fish
end
