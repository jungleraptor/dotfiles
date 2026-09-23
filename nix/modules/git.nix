{ config, pkgs, ... }:
{
  # Install the CLI without managing ~/.config/gh or changing authentication.
  home.packages = [ pkgs.gh ];
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "Isaac Torres";
        email = "isaac@isaactorz.dev";
      };
      core.editor = "nvim";
      init.defaultBranch = "main";
    };
    includes = [
      {
        condition = "gitdir:~/Perforce/";
        path = "~/.gitconfig.nv";
      }
      { path = "~/.gitconfig.local"; }
    ];
  };
  # Own Dotbot's old destination so a stale ~/.gitconfig cannot override HM.
  home.file.".gitconfig".text = config.xdg.configFile."git/config".text;
  xdg.configFile."git/config".enable = false;
}
