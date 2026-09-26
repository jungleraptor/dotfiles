{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    bat
    jq
    just
    ripgrep
  ];
  home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
  programs.fish = {
    enable = true;
    shellInit = lib.mkBefore ''
      # Support daemon and single-user Nix installations.
      for nix_init in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.fish "$HOME/.nix-profile/etc/profile.d/nix.fish"
        if test -r "$nix_init"
          source "$nix_init"
          break
        end
      end
      fish_add_path --path --move "$HOME/.nix-profile/bin"
      fish_add_path --path --move "$HOME/.local/bin"
    '';
    interactiveShellInit = builtins.readFile ../../config.fish;
    shellInitLast = ''
      if test -r "$HOME/.local.fish"
        source "$HOME/.local.fish"
      end
    '';
    shellAliases = {
      cat = "bat";
      tmux = "TERM=xterm-256color command tmux";
    };
  };
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;
    defaultCommand = "rg --files --hidden --follow --glob '!.git'";
    defaultOptions = [
      "--height 40%"
      "--reverse"
    ];
  };
  programs.direnv = {
    enable = true;
    enableFishIntegration = true;
  };
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = builtins.fromTOML (builtins.readFile ../../starship.toml);
  };
}
