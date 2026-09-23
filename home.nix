{ config, lib, ... }:

{
  imports = [
    ./nix/modules/shell.nix
    ./nix/modules/git.nix
    ./nix/modules/tmux.nix
    ./nix/modules/neovim.nix
    ./nix/modules/development.nix
  ];

  # Compatibility defaults, not the version of Nixpkgs/Home Manager to install.
  # Retain the value from the original Home Manager configuration.
  home.stateVersion = "22.05";
  programs.home-manager.enable = true;
  xdg.enable = true;

  # Dotbot linked this whole directory into the checkout. Writing init.lua
  # through that link would modify the checkout and leave two init files.
  home.activation.checkLegacyNeovim = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ -L ${lib.escapeShellArg "${config.xdg.configHome}/nvim"} ] ||
       [ -e ${lib.escapeShellArg "${config.xdg.configHome}/nvim/init.vim"} ]; then
      echo "Move the old ~/.config/nvim directory or symlink to a backup before switching." >&2
      echo "See INSTALL.md: Migrating existing dotfiles." >&2
      exit 1
    fi
  '';
}
