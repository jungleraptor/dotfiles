{ config, lib, pkgs, ... }:

let
  data = "${config.home.homeDirectory}/code/.nix-cache/ncps";
  supervisor = "/var/log/beacon/supervisor";
  supervisorctl = "${pkgs.python3Packages.supervisor}/bin/supervisorctl -c ${supervisor}/supervisord.conf";

  startNcps = pkgs.writeShellScript "start-ncps" ''
    set -eu
    export DATABASE_URL="sqlite:${data}/db.sqlite"
    ${pkgs.ncps}/bin/dbmate-ncps up
    exec ${pkgs.ncps}/bin/ncps serve \
      --server-addr=127.0.0.1:8501 \
      --cache-hostname=brix \
      --cache-storage-local=${data} \
      --cache-database-url="$DATABASE_URL" \
      --cache-upstream-url=http://127.0.0.1:8502 \
      --cache-upstream-public-key=applied:EpR2bpK4ExMQ38bsZmEMGJKo5qC/xboD/knAQMOMzAY=
  '';

  supervisorConfig = pkgs.writeText "ncps-supervisor.conf" ''
    [program:ncps]
    command=${startNcps}
    directory=${data}
    autostart=true
    autorestart=true
    stopasgroup=true
    killasgroup=true
    redirect_stderr=true
    stdout_logfile=${data}/ncps.log
    stdout_logfile_maxbytes=10MB
    stdout_logfile_backups=2
  '';
in
{
  home.activation.ncps = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run mkdir -p ${data}
    run ln -sfn ${supervisorConfig} ${supervisor}/conf.d/ncps.conf
    run ${supervisorctl} update ncps
  '';
}
