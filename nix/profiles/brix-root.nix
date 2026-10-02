{ ... }:
{
  imports = [
    ../platforms/linux.nix
    ../modules/nix-brix.nix
    ../modules/applied-cache-tunnel-brix.nix
    ../modules/ncps-brix.nix
  ];
  home.username = "root";
  home.homeDirectory = "/root";
}
