{ ... }:
{
  # These profiles manage CLI tools only, including containers without systemd.
  systemd.user.enable = false;
  xdg.configFile."clangd/config.yaml".source = ../../clangd.yaml;
  programs.fish.shellInit = ''
    if test -d /usr/local/cuda/bin
      fish_add_path --path --append /usr/local/cuda/bin
    end
  '';
}
