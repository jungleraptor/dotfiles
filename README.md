# dotfiles

Portable CLI tools and dotfiles managed by standalone **Home Manager** and Nix
flakes. macOS uses a normal user account; Linux supports both normal users and
root-run devboxes without systemd. Homebrew is not required.

Start with [INSTALL.md](INSTALL.md). Installation, building, and activation are
separate steps so you can inspect the result before changing your home directory.

## Configuration map

- `flake.nix` / `flake.lock`: pinned Home Manager, Nixpkgs, and editor dependencies.
- `home.nix`: shared modules and migration checks.
- `nix/profiles/`: username, home directory, and platform selection.
- `nix/modules/`: Fish, Starship, direnv, fzf, Git, tmux, Neovim, and development tools.
- `nix/platforms/`: Linux CUDA PATH support and platform-specific clangd locations.
- `nvim/init.vim` / `vimrc`: editor behavior, kept in Vimscript and Lua.
- `bootstrap`: installs or reuses Nix only; never activates dotfiles.
- `nix/cache.py`: builds a checked Brix generation on Applied and exports/imports
  a signed file cache, without activating Home Manager. See INSTALL.md.
- `tests/neovim.lua` / `nix/checks.nix`: checks that run without activating a profile.

Neovim uses a separately pinned Nixpkgs 25.11 package set to retain Neovim 0.11
and the legacy Tree-sitter API. Plugins, parser sources, and native dependencies
are pinned together. Normal packages and Home Manager follow 26.05.

Git credentials, project toolchains, CUDA, desktop applications, and login-shell
selection remain machine-owned. Runtime overrides live in `~/.local.fish`,
`~/.gitconfig.local`, and `~/.config/nvim/lsp-local.lua`.

The old Makefile, Brewfile, and Dotbot installer remain as migration references.
They are superseded by this workflow; do not run `make` or `./install` to apply
these Home Manager configs. There is no `PlugInstall`, `TSUpdate`, or TPM step.
