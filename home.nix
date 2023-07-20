{ config, pkgs, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = "parallels";
  home.homeDirectory = "/home/parallels";
  xdg.cacheHome = "/home/parallels/snap/alacritty/common/.cache";

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "22.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    userEmail = "isaac@isaactorz.dev";
    userName = "Isaac Torres";
    includes = [
      { path = "~/.gitconfig.local"; }
    ];
    extraConfig = {
      core = {
        editor = "nvim";
      };
      credential = {
        "https://gist.github.com" = {
          helper = "!/usr/bin/gh auth git-credential";
        };
        "https://github.com" = {
          helper = "!/usr/bin/gh auth git-credential";
        };
      };
      init = {
        defaultBranch = "main";
      };
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      aws = {
        format = "on [$symbol$profile]($style) ";
      };
      directory = {
        truncate_to_repo = false;
      };
      git_status = {
        disabled = true;
      };
      git_branch = {
        format = "on [$symbol$branch]($style) ";
      };
      python = {
        disabled = true;
      };
      cmake = {
        disabled = true;
      };
    };
  };

  programs.tmux = {
    enable = true;
    sensibleOnTop = false;
    escapeTime = 1;
    keyMode = "vi";
    mouse = true;
    prefix = "C-a";
    terminal = "xterm-256color";
    plugins = with pkgs.tmuxPlugins; [
      {
        plugin = dracula;
        extraConfig = "
          set -g @dracula-show-powerline true
          set -g @dracula-show-left-icon session
          set -g @dracula-show-battery false
          set -g @dracula-show-location false
          set -g @dracula-show-weather false
        ";
      }
    ];
    extraConfig = "
      set -g status-position top
      set -g terminal-overrides \",alacritty:Tc\"

      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      bind -r C-h select-window -t :-
      bind -r C-l select-window -t :+

      bind | split-window -h -c \"#{pane_current_path}\"
      bind - split-window -v -c \"#{pane_current_path}\"
    ";
  };
}
