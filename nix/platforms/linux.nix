{ ... }:
{
  # These profiles manage CLI tools only, including containers without systemd.
  systemd.user.enable = false;
  xdg.configFile."clangd/config.yaml".source = ../../clangd.yaml;
  programs.fish.shellInit = ''
    # Nix initialization prepends its profiles. Restore the OpenAI Git/GitHub
    # wrappers ahead of them when installed, matching the Brix login environment.
    fish_add_path --global --path --move /opt/openai/og/bin /opt/openai/native/bin

    if test -d /usr/local/cuda/bin
      fish_add_path --path --append /usr/local/cuda/bin
    end
  '';
}
