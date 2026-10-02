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
  # /root/code survives pod recreation; the default /dev/shm store does not.
  dotfiles.buildkite.credentialStorePath = "/root/code/.buildkite/credentials.json";
}
