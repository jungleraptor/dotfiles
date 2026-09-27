import "~/.config/just/config.just"

refresh profile=home_profile:
    nix run "path:$PWD#home-manager" -- switch --flake "path:$PWD#"{{quote(profile)}}
    ./nix/prepare-bootstrap {{quote(profile)}}

refresh-remote profile=home_profile:
    #!/usr/bin/env bash
    export NIX_CONFIG="${NIX_CONFIG:-}
    builders = ssh-ng://isaact@127.0.0.1:2222?remote-program=/nix/var/nix/profiles/default/bin/nix-daemon x86_64-linux $HOME/.ssh/id_rsa
    builders-use-substitutes = true
    max-jobs = 0"
    just refresh {{quote(profile)}}
