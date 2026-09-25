{ ... }:
{
  imports = [
    ../platforms/linux.nix
    ../modules/ncps.nix
  ];
  home.username = "isaact";
  home.homeDirectory = "/home/dev-user";
}
