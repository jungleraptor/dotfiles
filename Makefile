all: fish vim tmux

pyyaml:
	sudo apt install -y python3-yaml

dotbot: pyyaml
	mkdir -p ~/.config/fish/completions
	./install

brew: dotbot
	/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

bundle: brew
	/home/linuxbrew/.linuxbrew/bin/brew bundle

fish: bundle
	sudo sh -c 'echo "/home/linuxbrew/.linuxbrew/bin/fish" >> /etc/shells'
	sudo chsh -s /home/linuxbrew/.linuxbrew/bin/fish isaac

vim: bundle
	curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	/home/linuxbrew/.linuxbrew/bin/nvim --headless +PlugInstall +qall

tmux: dotbot
	# FIXME - this step isn't idempotent
	git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
	env PATH=/home/linuxbrew/.linuxbrew/bin:$$PATH ~/.tmux/plugins/tpm/scripts/install_plugins.sh
