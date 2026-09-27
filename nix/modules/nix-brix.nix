{ ... }:
{
  imports = [
    (import ./nix-post-build.nix {
      caches = [ "http://127.0.0.1:8501" ];
    })
  ];

  xdg.configFile."nix/nix.conf".text = ''
    substituters = http://127.0.0.1:8501
    extra-trusted-public-keys = brix:tWgx+Wc0+XPT/OuuTlQ3dsaoztQzB6iutLgx3tEiwWY=
    narinfo-cache-negative-ttl = 0

    builders =
    max-jobs = 1
  '';
}
