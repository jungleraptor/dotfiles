{ config, lib, pkgs, ... }:

let
  data = "${config.home.homeDirectory}/code/.nix-cache/ncps";
  supervisor = "/var/log/beacon/supervisor";
  supervisorctl = "${pkgs.python3Packages.supervisor}/bin/supervisorctl -c ${supervisor}/supervisord.conf";

  startTunnel = pkgs.writeShellScript "start-applied-cache-tunnel" ''
    set -eu
    export HOME=${lib.escapeShellArg config.home.homeDirectory}
    export SSH_BIN=${pkgs.openssh}/bin/ssh
    # Keep the supervisor process alive while the relay or certificate is unavailable.
    while true; do
      ${pkgs.bash}/bin/bash ${../applied-cache-tunnel} 8502 || true
      ${pkgs.coreutils}/bin/sleep 5
    done
  '';

  supervisorConfig = pkgs.writeText "applied-cache-tunnel-supervisor.conf" ''
    [program:applied-cache-tunnel]
    command=${startTunnel}
    directory=${data}
    autostart=true
    autorestart=true
    startsecs=0
    stopasgroup=true
    killasgroup=true
    redirect_stderr=true
    stdout_logfile=${data}/applied-cache-tunnel.log
    stdout_logfile_maxbytes=10MB
    stdout_logfile_backups=2
  '';
in
{
  home.activation.appliedCacheTunnel = lib.hm.dag.entryBetween [ "ncps" ] [ "linkGeneration" "installPackages" ] ''
    run mkdir -p ${data}
    run ln -sfn ${supervisorConfig} ${supervisor}/conf.d/applied-cache-tunnel.conf
    run ${supervisorctl} update applied-cache-tunnel
    if ! ${supervisorctl} status applied-cache-tunnel >/dev/null; then
      run ${supervisorctl} start applied-cache-tunnel
    fi
    # Updating this service can interrupt an existing tunnel reused by bootstrap.
    # Wait only when activation itself needs that endpoint; local recovery and
    # bootstrap's independent temporary tunnel must also work without it.
    if [ "''${DOTFILES_BOOTSTRAP_APPLIED_CACHE:-}" = http://127.0.0.1:8502 ]; then
      run ${pkgs.curl}/bin/curl --fail --silent --show-error \
        --connect-timeout 2 --max-time 2 \
        --retry 10 --retry-all-errors --retry-delay 1 --retry-max-time 20 \
        http://127.0.0.1:8502/nix-cache-info >/dev/null
    fi
  '';
}
