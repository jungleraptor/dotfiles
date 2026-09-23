{ ... }:
{
  imports = [ ../platforms/linux.nix ];
  home.username = "root";
  home.homeDirectory = "/root";
  # No systemd user services, login-shell changes, or GitHub auth setup.
}
