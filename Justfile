refresh profile="brix-root":
    nix run "path:$PWD#home-manager" -- switch --flake "path:$PWD#{{profile}}"
    ./nix/prepare-bootstrap {{profile}}

refresh-remote profile="brix-root":
    #!/usr/bin/env bash
    export NIX_CONFIG="${NIX_CONFIG:-}
    builders = ssh-ng://isaact@127.0.0.1:2222?remote-program=/nix/var/nix/profiles/default/bin/nix-daemon x86_64-linux $HOME/.ssh/id_rsa
    builders-use-substitutes = true
    max-jobs = 0"
    just refresh "{{profile}}"
