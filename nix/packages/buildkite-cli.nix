{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  versionCheckHook,
}:

let
  version = "3.59.1";
  # Official release checksums. The pinned nixpkgs CLI predates device login
  # and the /dev/shm credential store needed on headless Brix hosts.
  releases = {
    x86_64-linux = {
      platform = "linux_amd64";
      extension = "tar.gz";
      hash = "sha256-75j93MJnlrpAIVS4Ki9zhlZNQAbxD2kWbbLGSgEf9y4=";
    };
    aarch64-linux = {
      platform = "linux_arm64";
      extension = "tar.gz";
      hash = "sha256-dv+V9DUTOeJphnKCMyOYpcBHJ3uRk+UyLWaZmRlhS3k=";
    };
    aarch64-darwin = {
      platform = "macOS_arm64";
      extension = "zip";
      hash = "sha256-7LmyCQam4c5ZBrrHwJnxyKpIfhVLfvHdQlvKEwlnw5Q=";
    };
  };
  release = releases.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported Buildkite CLI platform");
in
stdenvNoCC.mkDerivation {
  pname = "buildkite-cli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/buildkite/cli/releases/download/v${version}/bk_${version}_${release.platform}.${release.extension}";
    inherit (release) hash;
  };
  sourceRoot = "bk_${version}_${release.platform}";

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isDarwin [ unzip ];
  dontConfigure = true;
  dontBuild = true;
  # Preserve upstream's signed Darwin binary; Linux releases are already static.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bk "$out/bin/bk"
    install -Dm644 LICENSE.md "$out/share/doc/buildkite-cli/LICENSE.md"
    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;
  versionCheckProgram = "${builtins.placeholder "out"}/bin/bk";

  meta = {
    description = "Command line interface for Buildkite";
    homepage = "https://github.com/buildkite/cli";
    changelog = "https://github.com/buildkite/cli/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "bk";
    platforms = builtins.attrNames releases;
  };
}
