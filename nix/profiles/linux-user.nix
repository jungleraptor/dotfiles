{ ... }:
{
  imports = [ ../platforms/linux.nix ];
  # Change both values for a devbox with a different login name/home directory.
  home.username = "isaac";
  home.homeDirectory = "/home/isaac";
}
