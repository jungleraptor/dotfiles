{ ... }:
{
  imports = [
    ../platforms/linux.nix
    ../modules/ncps-brix.nix
  ];
  home.username = "root";
  home.homeDirectory = "/root";
}
