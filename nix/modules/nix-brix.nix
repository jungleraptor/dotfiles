{ config, ... }:
{
  xdg.configFile."nix/nix.conf".text = ''
    substituters = http://127.0.0.1:8501
    extra-trusted-public-keys = brix:tWgx+Wc0+XPT/OuuTlQ3dsaoztQzB6iutLgx3tEiwWY=

    builders = ssh-ng://isaact@127.0.0.1:2222?remote-program=/nix/var/nix/profiles/default/bin/nix-daemon x86_64-linux ${config.home.homeDirectory}/.ssh/id_rsa
    builders-use-substitutes = true
    max-jobs = 0
  '';
}
