# Notes

Steps for getting a new machine setup:
- clone dotfiles repo (this should be public): `git clone git@github.com:jungleraptor/dotfiles.git`
- install brew `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- install devtools: `brew bundle`
- install pyyaml: `sudo apt-get install python-yaml` (on ubuntu 20.04 dotbot ends up using python 2 and trying to use pip doesn't work)
- install dotfiles: `./install` (note: maybe this needs to be run before brew since brew seemed to leave this in a messy state)
- install vim plug: `sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim`
- run `:PlugInstall` in vim: `nvim --headless +PlugInstall +qall`
- install tmux plugin manager: `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`
- Install the plugins: ~/.tmux/plugins/tpm/scripts/install_plugins.sh
- On a new chrombook fonts are already synced (win for crostini) - but for future reference: https://www.reddit.com/r/Crostini/comments/s1dgvk/best_way_to_get_nerd_fonts_on_crostini/
