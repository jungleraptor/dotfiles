{ caches, restartDaemon ? false }:
{ config, lib, pkgs, ... }:

let
  sudo = lib.optionalString (config.home.username != "root") "sudo ";
  include = "!include ${config.xdg.configHome}/nix/nix.conf";
  hook = pkgs.writeShellScript "ncps-post-build" ''
    set -eu
    set -f
    export IFS=' '
    for cache in ${lib.escapeShellArgs caches}; do
      echo "Caching build outputs in $cache"
      /nix/var/nix/profiles/default/bin/nix copy \
        --to "$cache/upload?compression=zstd" $OUT_PATHS
    done
  '';
in
{
  xdg.configFile."nix/nix.conf".text = lib.mkAfter ''
    post-build-hook = ${hook}
  '';

  # Make these Nix settings available to the daemon for builds requested over SSH.
  home.activation.ncpsPostBuild = lib.hm.dag.entryAfter [ "ncps" "reloadSystemd" ] ''
    if ! grep -qxF '${include}' /etc/nix/nix.custom.conf; then
      run ${sudo}tee -a /etc/nix/nix.custom.conf >/dev/null <<'EOF'

    ${include}
    EOF
    fi
    ${lib.optionalString restartDaemon "run ${sudo}systemctl restart nix-daemon.service"}
    run env OUT_PATHS="$newGenPath" ${hook}
  '';
}
