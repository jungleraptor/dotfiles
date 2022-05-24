# for npm to work right
# see https://stackoverflow.com/questions/52979927/npm-warn-checkpermissions-missing-write-access-to-usr-local-lib-node-modules
npm set prefix ~/.npm
set PATH $HOME/.npm/bin $PATH
set PATH ./node_modules/.bin $PATH
set PATH $HOME/.cargo/bin $PATH

# mainly for haskell
set PATH $PATH $HOME/.local/bin

# fzf
set -x FZF_DEFAULT_OPTS "--height 40% --reverse"

# cmake defaults
set -x CMAKE_C_COMPILER_LAUNCHER sccache
set -x CMAKE_CXX_COMPILER_LAUNCHER sccache
set -x CMAKE_GENERATOR Ninja

# direnv hooks
direnv hook fish | source
