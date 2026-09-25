{ config, lib, pkgs, ... }:

let
  data = "${config.home.homeDirectory}/code/.nix-cache/ncps";
  database = "sqlite:${data}/db.sqlite";
in
{
  imports = [
    (import ./ncps-post-build.nix {
      caches = [ "http://127.0.0.1:8501" ];
      restartDaemon = true;
    })
  ];

  systemd.user.enable = lib.mkForce true;
  systemd.user.startServices = true;

  systemd.user.services.ncps = {
    Unit.Description = "Nix cache proxy";
    Install.WantedBy = [ "default.target" ];

    Service = {
      Environment = "DATABASE_URL=${database}";
      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p ${data}"
        "${pkgs.ncps}/bin/dbmate-ncps up"
      ];
      ExecStart = lib.concatStringsSep " " [
        "${pkgs.ncps}/bin/ncps serve"
        "--server-addr=127.0.0.1:8501"
        "--cache-hostname=applied"
        "--cache-storage-local=${data}"
        "--cache-database-url=${database}"
        "--cache-upstream-url=https://cache.nixos.org"
        "--cache-upstream-public-key=cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "--cache-allow-put-verb=true"
      ];
      Restart = "on-failure";
    };
  };
}
