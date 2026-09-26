{ config, lib, pkgs, ... }:

let
  logs = "${config.home.homeDirectory}/Library/Logs";
  sshOptions = [
    "-o" "BatchMode=yes"
    "-o" "ExitOnForwardFailure=yes"
    "-o" "ServerAliveInterval=15"
    "-o" "ServerAliveCountMax=4"
    "-o" "ControlMaster=no"
    "-o" "ControlPath=none"
  ];
  agent = name: command: schedule: {
    enable = true;
    config = {
      ProgramArguments = command;
      RunAtLoad = true;
      EnvironmentVariables.PATH = lib.concatStringsSep ":" [
        "${config.home.homeDirectory}/.brix/bin"
        "${config.home.homeDirectory}/.local/bin"
        "${config.home.homeDirectory}/.nix-profile/bin"
        "/opt/homebrew/bin"
        "/usr/local/bin"
        "/usr/bin"
        "/bin"
        "/usr/sbin"
        "/sbin"
      ];
      StandardOutPath = "${logs}/${name}.log";
      StandardErrorPath = "${logs}/${name}.log";
    } // schedule;
  };
  tunnel = name: command: agent name command {
    KeepAlive = true;
    ThrottleInterval = 30;
  };
in
{
  home.activation.sshTunnelLogs = lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "writeBoundary" ] ''
    run mkdir -p ${lib.escapeShellArg logs}
  '';

  launchd.agents = {
    applied-ssh-credentials = agent "applied-ssh-credentials" [
      "${pkgs.bash}/bin/bash"
      "${../refresh-ssh-credentials}"
    ] {
      StartInterval = 600;
    };

    # Mac :2222 -> Applied :22.
    applied-ssh-tunnel = tunnel "applied-ssh-tunnel" (
      [
        "/usr/bin/ssh"
        "-NT"
        "-o" "RemoteCommand=none"
        "-L" "127.0.0.1:2222:127.0.0.1:22"
      ] ++ sshOptions ++ [ "applied-dev" ]
    );

    # Brix :2222 -> Mac :2222.
    brix-ssh-relay = tunnel "brix-ssh-relay" (
      [
        "/usr/bin/env" "brix" "ssh"
        "-c" "fleet-research-agent-hub-0"
        "-n" "isaact"
        "-N"
        "-R" "127.0.0.1:2222:127.0.0.1:2222"
        "codex-box-0"
        "--"
      ] ++ sshOptions
    );
  };
}
