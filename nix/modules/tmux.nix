{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.tmux = {
    enable = true;
    sensibleOnTop = false;
    escapeTime = 1;
    keyMode = "vi";
    mouse = true;
    prefix = "C-a";
    terminal = "xterm-256color";
    shell = lib.getExe pkgs.fish;
    plugins = [
      {
        plugin = pkgs.tmuxPlugins.dracula;
        extraConfig = ''
          set -g @dracula-show-powerline true
          set -g @dracula-show-flags true
          set -g @dracula-show-left-icon session
          set -g @dracula-show-location false
          set -g @dracula-show-weather false
          set -g @dracula-show-battery false
          set -g status-position top
        '';
      }
      {
        plugin = pkgs.tmuxPlugins.yank;
        extraConfig = "set -g @yank_selection_mouse 'clipboard'";
      }
    ];
  };
  home.file.".tmux.conf".text = config.xdg.configFile."tmux/tmux.conf".text;
  xdg.configFile."tmux/tmux.conf" = {
    enable = false;
    # HM's extraConfig runs after plugins. Preserve the old ordering instead:
    # generated defaults (500), personal settings (900), then plugins (1000).
    text = lib.mkOrder 900 (builtins.readFile ../../tmux.conf);
  };
}
