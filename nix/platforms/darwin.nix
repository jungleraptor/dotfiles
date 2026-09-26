{ ... }:
{
  home.file."Library/Preferences/clangd/config.yaml".source = ../../clangd.yaml;
  # The application remains machine-owned; Home Manager supplies its config.
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
