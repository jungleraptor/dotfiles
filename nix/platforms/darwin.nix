{ pkgs, ... }:
{
  home.packages = [
    pkgs.alacritty
    pkgs.nerd-fonts.hack
  ];
  # Copy real app bundles so Spotlight can index them. Keep Home Manager's
  # synchronized directory separate from other machine-installed applications.
  targets.darwin.linkApps.enable = false;
  targets.darwin.copyApps = {
    enable = true;
    directory = "/Applications/Home Manager Apps";
  };

  home.file."Library/Preferences/clangd/config.yaml".source = ../../clangd.yaml;
  xdg.configFile."alacritty/alacritty.toml".source = ../../alacritty.toml;

  programs.fish.shellInit = ''
    # Match the OpenAI login environment without globally activating its venv.
    fish_add_path -gPm \
      "$HOME/.openai/bin" \
      "/Library/Application Support/OpenAI/bin" \
      "$HOME/code/openai/project/dotslash-gen/bin"
    # Prefer Home Manager tools; retain Homebrew for machine-owned packages.
    fish_add_path -gPam /opt/homebrew/bin /opt/homebrew/sbin "$HOME/.cargo/bin"
  '';
}
