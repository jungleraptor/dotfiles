{ ... }:
{
  imports = [
    (import ./nix-post-build.nix {
      caches = [ "http://127.0.0.1:8501" ];
      restartDaemon = true;
    })
  ];

  xdg.configFile."nix/nix.conf".text = ''
    substituters = http://127.0.0.1:8501
    extra-trusted-public-keys = applied:EpR2bpK4ExMQ38bsZmEMGJKo5qC/xboD/knAQMOMzAY=
  '';
}
