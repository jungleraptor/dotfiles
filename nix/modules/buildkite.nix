{ lib, pkgs, ... }:
{
  # bk and its OAuth credential store remain machine-owned.
  home.packages = [
    (pkgs.writeShellScriptBin "dotfiles-buildkite-token" ''
      export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.jq ]}:$HOME/.local/bin:$HOME/.nix-profile/bin:$PATH"
      ${builtins.readFile ../buildkite/token.sh}
    '')
  ];
  xdg.configFile."buildkite/oauth-env.sh".source = ../buildkite/env.sh;
  xdg.configFile."buildkite/oauth-env.fish".source = ../buildkite/env.fish;

  programs.fish.shellInitLast = lib.mkAfter ''
    source "$HOME/.config/buildkite/oauth-env.fish"
  '';

  # Preserve the machine's OpenAI startup setup. Bash login shells read this
  # even when the user's interactive shell is Fish.
  home.activation.buildkiteBashProfile = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    buildkite_profile="$HOME/.bash_profile"
    buildkite_source='[ ! -r "$HOME/.config/buildkite/oauth-env.sh" ] || . "$HOME/.config/buildkite/oauth-env.sh"'
    if ! ${pkgs.gnugrep}/bin/grep -qxF "$buildkite_source" "$buildkite_profile" 2>/dev/null; then
      if [ -e "$buildkite_profile" ] && [ ! -e "$buildkite_profile.before-buildkite-oauth" ]; then
        run cp -p "$buildkite_profile" "$buildkite_profile.before-buildkite-oauth"
      fi
      if [ -n "''${DRY_RUN_CMD:-}" ]; then
        echo "Would add Buildkite OAuth environment loading to $buildkite_profile"
      else
        printf '\n# Buildkite OAuth environment (dotfiles)\n%s\n' "$buildkite_source" >> "$buildkite_profile"
      fi
    fi
  '';

  # A cached shell snapshot also caches expiring credentials. Change just this
  # setting in the machine-owned Codex config, preserving its other settings.
  home.activation.buildkiteCodexShell = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${pkgs.python3}/bin/python3 ${../buildkite/configure-codex.py} "$HOME/.codex/config.toml"
  '';
}
