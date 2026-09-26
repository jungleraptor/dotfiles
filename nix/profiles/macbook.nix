{ ... }:
{
  imports = [
    ../platforms/darwin.nix
    ../modules/ssh-tunnels-darwin.nix
  ];
  home.username = "isaact";
  home.homeDirectory = "/Users/isaact";
}
