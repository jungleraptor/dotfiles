{ pkgs, home }:
let
  cfg = home.config;
in
{
  # Building the activation package does not run it or change the user's home.
  home = home.activationPackage;
  neovim = pkgs.runCommand "dotfiles-neovim-smoke" { } ''
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    export XDG_STATE_HOME="$HOME/.local/state"
    export XDG_CACHE_HOME="$HOME/.cache"
    export NVIM_LOG_FILE="$TMPDIR/nvim.log"
    mkdir -p "$XDG_CONFIG_HOME/nvim" "$XDG_DATA_HOME/nvim/site/pack"
    ln -s ${cfg.xdg.configFile."nvim/init.lua".source} "$XDG_CONFIG_HOME/nvim/init.lua"
    ln -s ${cfg.xdg.dataFile."nvim/site/pack/hm".source} "$XDG_DATA_HOME/nvim/site/pack/hm"
    ${cfg.programs.neovim.finalPackage}/bin/nvim --headless -i NONE -c "luafile ${../tests/neovim.lua}"
    touch "$out"
  '';
  fish = pkgs.runCommand "dotfiles-fish-syntax" { } ''
    ${pkgs.fish}/bin/fish --no-execute ${cfg.xdg.configFile."fish/config.fish".source}
    touch "$out"
  '';
}
