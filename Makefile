update:
	./install
	TERM=dumb nvim +PlugInstall +qall >vim.log 2>&1
	fish -c 'fisher update'
