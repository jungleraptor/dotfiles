# for npm to work right
# see https://stackoverflow.com/questions/52979927/npm-warn-checkpermissions-missing-write-access-to-usr-local-lib-node-modules
set PATH $HOME/.cargo/bin $PATH

# mainly for haskell
set PATH $HOME/.local/bin $PATH

set PATH $HOME/bin $PATH

# fzf
set -x FZF_DEFAULT_OPTS "--height 40% --reverse"

# cmake defaults
set -x CMAKE_C_COMPILER_LAUNCHER sccache
set -x CMAKE_CXX_COMPILER_LAUNCHER sccache
set -x CMAKE_GENERATOR Ninja

# aliases
alias vim=nvim

# for some reason this is necessary to make tmux true color work inside of docker.
alias tmux="TERM=xterm-256color command tmux"

# On ubuntu `bat` is installed as `batcat` due to a name clash
# with another package.
# alias cat=batcat

# direnv hooks
# direnv hook fish | source

# starship
starship init fish | source

set -q GHCUP_INSTALL_BASE_PREFIX[1]; or set GHCUP_INSTALL_BASE_PREFIX $HOME ; set -gx PATH $HOME/.cabal/bin /home/parallels/.ghcup/bin $PATH # ghcup-env

# try to source a machine specific config
if test -e ~/.local.fish
  source ~/.local.fish
end
