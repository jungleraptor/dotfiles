refresh profile="brix-root":
    nix run "path:$PWD#home-manager" -- switch --flake "path:$PWD#{{profile}}"
