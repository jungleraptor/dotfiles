# Installing and learning the Home Manager setup

The steps below are deliberately separate:

1. **Install Nix:** provides the package store and build tool.
2. **Evaluate/build:** validates configuration and creates a generation in the store.
3. **Inspect/back up:** review the generated files and prepare existing dotfiles.
4. **Switch:** links that generation into your home directory and installs its packages.

Only step 4 activates dotfiles. Building a generation does not activate it.

## 1. Install Nix

On a fresh machine, from this checkout:

```sh
./bootstrap
```

This downloads a checksum-verified NixOS community installer, enables flakes, and
stops after installing Nix. Use `./bootstrap --yes` for a noninteractive install.
It reuses an existing Nix installation and does not modify shell startup files.

Supported bootstrap targets:

| Machine | Installation |
| --- | --- |
| Apple Silicon macOS | Multi-user installation with launchd; requires administrator access |
| x86-64 or ARM64 Linux with systemd | Multi-user installation; requires administrator access |
| Root Linux container without systemd | Root-only installation with `--init none` |

For non-root Linux without systemd, first arrange an existing Nix installation or
a writable `/nix` and follow the official [single-user installation instructions](https://nix.dev/manual/nix/stable/installation/installing-binary.html#single-user-installation).
The bootstrap does not silently select a root-only installation for a non-root account.

In Bash or Zsh, load the NixOS installer environment into your current shell:

```sh
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
nix --version
```

In Fish, source the adjacent `nix-daemon.fish` file instead. For an upstream
single-user install, use `~/.nix-profile/etc/profile.d/nix.sh` (or `nix.fish`).
Because shell profiles are untouched, repeat this in a fresh shell until you
choose to add the source line yourself. Home Manager's Fish config loads Nix.

The installer may report shell self-test warnings with `--no-modify-profile`:
those shells have not sourced Nix yet. Verify `nix --version` after sourcing it.

### This Brix box

Nix 2.35.2 was installed in `/nix` with `--init none --no-modify-profile`.
A local derivation built successfully. No Home Manager generation was activated.

Implementation checks passed: evaluation of all four profiles and all platform
checks, Nix formatting, bootstrap syntax/reuse, Fish 4.7.1 syntax, and an isolated
Neovim 0.11.7 check using the locked plugin sources and nine compiled parsers.
The isolated editor check covered mappings, queries, server command selection,
and the LSP attachment callback. It did not test an activated home or connections
to real language servers; servers and toolchains are now supplied externally.

Public Nix downloads failed during TLS on the Research boxes, including a regular
Brix devbox on `f81`. Changing the pool's sandbox setting did not restore access.
The separate Applied devbox named `applied` is x86_64 Linux and can reach
`cache.nixos.org/nix-cache-info` and download Bazel (checked by hand).

Use the [Applied builder workflow](#build-on-applied-and-export-for-brix) below
to build there and transfer a file cache to Research. The complete Home Manager
build remains unverified until that builder run finishes. Do not disable TLS
verification or disable substitutes to attempt a full source build.

The persistent checkout does not by itself preserve `/nix`. On a recreated box,
provision Nix again before using existing store symlinks, or arrange persistence
for the complete `/nix` installation (store, database, and profiles). A restart
that keeps the existing filesystem is different from recreating the box.

## 2. Select and inspect a profile

| Flake profile | System | Default account/home |
| --- | --- | --- |
| `brix-root` | x86_64-linux | root, `/root` |
| `linux-user` | x86_64-linux | isaac, `/home/isaac` |
| `linux-arm` | aarch64-linux | isaac, `/home/isaac` |
| `macbook` | aarch64-darwin | isaact, `/Users/isaact` |

The Mac profile is configured for `isaact`. If a Linux devbox uses another login,
edit both account fields in `nix/profiles/linux-user.nix` to match it. These values
are explicit configuration, not inferred from the shell running Nix.

The examples below use Bash/Zsh and the Brix profile:

```sh
dotfiles_profile=brix-root
nix flake show "path:$PWD"
nix flake check "path:$PWD" --all-systems --no-build
```

`--no-build` evaluates the checks for all supported systems. It does not prove
that the packages build or that runtime tests pass. Actual macOS builds require
a Mac or a configured macOS builder.

`path:$PWD` includes the new files while they are still untracked. Once the new
files are added to Git, `.` can be used instead. Keep secrets outside this
checkout: Nix copies configuration sources into its store.

The lockfile fixes exact versions. None of the build/switch commands below
update it. `home.stateVersion = "22.05"` preserves compatibility defaults from
the original configuration; it is not a package version and should not be bumped
as part of routine upgrades.

## 3. Build without activating

Run the Home Manager CLI from this flake's pinned input:

```sh
nix run "path:$PWD#home-manager" -- build --flake "path:$PWD#$dotfiles_profile"
ls -la result/home-files
less result/home-files/.gitconfig
less result/home-files/.tmux.conf
```

`result` points to the generated environment in `/nix/store`. Your live dotfiles
are unchanged. The full checks also build the profile and run Neovim and Fish
checks in temporary homes:

```sh
nix flake check "path:$PWD"
```

The editor check loads the configured plugins, parsers, queries, mappings, and
optional language-server settings. It does not require installed language servers.
Test language-server behavior with your projects' toolchains after activation.

### Build on Applied and export for Brix

The builder's login does not need to be root. It builds the **`brix-root`**
profile for the destination's `root` account and `/root` home, and never
activates that configuration on the builder. Both machines must be x86_64 Linux
with Nix and Python 3 installed. The helper finds Nix in its usual installation
directory if the current shell has not loaded it yet.

#### Get this working tree onto `applied`

The migration currently includes uncommitted and untracked files. A fresh clone
does not contain them yet. From your Mac, copy this checkout into a separate
directory, then send it to the Applied devbox using its `dbox` SSH alias:

```sh
mkdir -p "$HOME/code/dotfiles-builder"
brix rsync -c fleet-research-agent-hub-0 -n isaact --pods codex-box-0 -- \
  -az --exclude=.git --exclude=result --exclude='result-*' \
  :/root/code/dotfiles/ "$HOME/code/dotfiles-builder/"
ssh applied 'mkdir -p "$HOME/code/dotfiles-builder"'
rsync -az "$HOME/code/dotfiles-builder/" applied:code/dotfiles-builder/
dbox ssh applied
```

These commands copy the dotfiles checkout, not Research workloads or credentials.
Run transfers through your Mac's working Brix and Applied connections; the
Research box does not have the Mac's Secretive SSH agent. If an SSH alias was
not configured, use `dbox ssh applied` to establish the supported connection
before configuring the file transfer.

#### Build, check, and export

In the Applied shell, preferably inside tmux:

```sh
cd ~/code/dotfiles-builder
python3 nix/cache.py export "$HOME/dotfiles-cache/brix-root-v1"
```

The command:

1. Archives this working tree and its locked flake inputs into the Nix store.
2. Builds the root profile from that immutable source snapshot.
3. Runs the existing Neovim and Fish checks.
4. Copies the generation's complete runtime closure and flake sources into
   `brix-root-v1/cache`, signing the cache with a private key kept on the builder.
5. Writes `manifest.json` only after the build, checks, and export succeed.

It keeps garbage-collection roots under the bundle's `roots` directory. Keep
the bundle at that location until transfer finishes. The default signing key is
`~/.local/state/dotfiles-cache/signing-key`; preserve it on the builder and do not
transfer it. Only `cache-public-key` accompanies the bundle. If you use
`--key-file`, its location must also be outside the checkout and bundle.

A failed export can be retried in the same directory. A completed bundle is
immutable for this helper: use a new directory such as `brix-root-v2` for a new
generation. Nix reuses unchanged packages already present on the builder.

#### Transfer through the Mac to persistent Research storage

After the export reports success, run on the Mac:

```sh
mkdir -p "$HOME/dotfiles-cache/brix-root-v1"
rsync -az applied:dotfiles-cache/brix-root-v1/ "$HOME/dotfiles-cache/brix-root-v1/"
brix rsync -c fleet-research-agent-hub-0 -n isaact --pods codex-box-0 -- \
  -az "$HOME/dotfiles-cache/" :/root/code/.nix-cache/
```

Repeat the last command with `--pods devbox-0` for the other Research box. Use
that box's actual cluster if you are targeting the new `f81` builder instead.
The cache lives outside the dotfiles checkout on `/root/code`'s persistent
volume. Transfer only completed bundles, and preserve the public key from your
own builder through these authenticated connections.

#### Import and verify, without switching

In each destination's root shell:

```sh
cd /root/code/dotfiles
python3 nix/cache.py import /root/code/.nix-cache/brix-root-v1
```

Import registers the packages and flake sources in `/nix/store`, verifies cache
signatures using the bundle's public key, registers local GC roots, and evaluates
the archived flake offline to check that it names the expected generation.
Public substituters are disabled for the import; trust is scoped to that
command. No global Nix settings or active Home Manager profile are changed.
The script prints the generation directory so you can inspect `home-files`.

The transfer helper was tested with a small local build: an empty store rejected
the generation without the signing key, then imported and evaluated it offline
with the key. Re-import and untracked Git files were also checked. Separately,
the real `brix-root` configuration evaluated offline in a fresh store/cache
containing only its archived flake sources. These checks do not replace the full
Home Manager build and runtime checks on Applied.

To preview activation **after** reviewing the migration/backups below, use the
Home Manager executable inside that generation, with the `source` path recorded
in `manifest.json`:

```sh
dotfiles_bundle=/root/code/.nix-cache/brix-root-v1
dotfiles_generation=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["generation"])' "$dotfiles_bundle/manifest.json")
dotfiles_source=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["source"])' "$dotfiles_bundle/manifest.json")
"$dotfiles_generation/home-path/bin/home-manager" -n switch \
  --flake "path:$dotfiles_source#brix-root" --option substituters ''
```

The `-n` is Home Manager's dry-run flag. Remove it only when you choose to
activate. Use the archived source for this first switch so it matches the
generation that was built and transferred. See the normal migration steps below
for file collisions and backups.

This bundle supports that exact generation. It does **not** contain every
build-time dependency needed for arbitrary edits or new packages; build/export
a new bundle from Applied when those dependencies change. Flake inputs alone do
not provide all package sources or compilers.

For later builds that should consult the local cache, the relevant Nix option is
`--option substituters file:///root/code/.nix-cache/brix-root-v1/cache`, together
with the cache's trusted public key. Nix's `--offline` flag disables substituters,
including file caches; the import helper imports first and evaluates offline
afterward. Missing build inputs still require another builder export.

The persistent cache does not preserve the running `/nix` installation. After
pod recreation, restore/provision Nix first and rerun the import. An offline Nix
installer is not included in this bundle.

## 4. Migrating existing dotfiles

Before the first switch, review your existing Git config. Preserve machine/work
identity, credential helpers, and includes in `~/.gitconfig.local`. Do not overwrite
existing local override files. Home Manager does not manage `~/.config/gh` or SSH
keys, and does not run any authentication setup.

The old Dotbot configuration symlinks the **whole Neovim directory** to this
checkout. Move that symlink aside before switching; do not copy the new init.lua
through it. The activation guard also rejects an old init.vim alongside the new
init.lua. This prevents modifying the checkout or leaving conflicting init files.

After inspecting the build, this optional first-migration snippet backs up the
destinations the new configuration will manage. `mv` moves symlinks themselves,
preserving the checkout they pointed to. Run this only when you are ready to
replace those files:

```sh
dotfiles_backup="$HOME/.local/state/dotfiles-backups/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$dotfiles_backup"
for dotfiles_relative in \
  .config/nvim .config/fish/config.fish \
  .config/starship.toml .gitconfig .config/git/config .tmux.conf \
  .config/tmux/tmux.conf .vim .vimrc \
  .config/clangd/config.yaml Library/Preferences/clangd/config.yaml
do
  if [ -e "$HOME/$dotfiles_relative" ] || [ -L "$HOME/$dotfiles_relative" ]; then
    mkdir -p "$(dirname "$dotfiles_backup/$dotfiles_relative")"
    mv "$HOME/$dotfiles_relative" "$dotfiles_backup/$dotfiles_relative"
  fi
done
printf 'Backup: %s\n' "$dotfiles_backup"
```

If a destination is managed by the devbox image and cannot be moved, stop and
adapt that profile's file ownership first. Do not force-overwrite injected config.
Home Manager refuses unexpected file collisions rather than deleting them.

## 5. Preview, then switch when ready

```sh
nix run "path:$PWD#home-manager" -- -n switch --flake "path:$PWD#$dotfiles_profile"
# The following command activates the new dotfiles:
nix run "path:$PWD#home-manager" -- switch --flake "path:$PWD#$dotfiles_profile"
```

Run activation as the account named by the profile. Use root only for `brix-root`;
do not use `sudo home-manager switch` for your normal Mac/Linux account.

After switching, open Fish explicitly:

```sh
"$HOME/.nix-profile/bin/fish"
```

Login-shell changes are deliberately separate. You can configure your terminal
to start the profile's Fish binary without changing `/etc/shells` or `chsh`.

Check `type -a nvim fish git`, start tmux, and open representative Python, Rust,
C++, and Lua projects. Home Manager does not install LLVM/Clang, compilers,
language servers, or standalone Python/Node/Rust toolchains. Neovim uses
`clangd`, `pyright-langserver`, `rust-analyzer`, and `lua-language-server` from
PATH, or the executable paths in `lsp-local.lua`. Missing servers do not autostart;
syntax highlighting and non-LSP completion remain available. Launch Neovim from
the project's environment, and restart it after installing a server or changing
PATH. Plugins and precompiled Tree-sitter parsers remain Nix-managed; their build
dependencies are separate from the tools installed into your home environment.

C++ still needs a suitable `compile_commands.json`. Rust
uses `rust-project.json` when present at the project root, otherwise normal
Cargo discovery. Python uses your project's Python environment. The tools do
not replace project build systems or install CUDA.

## Local overrides

- `~/.local.fish`: sourced after the shared Fish configuration.
- `~/.gitconfig.local`: included after the shared Git settings and Perforce include.
- `~/.config/nvim/lsp-local.lua`: return a table of per-server overrides, for example:

```lua
return {
  clangd = {
    cmd = { '/path/to/project/clangd', '--header-insertion=never' },
  },
}
```

Neovim settings stay in `nvim/init.vim` and `vimrc`; plugin and parser lists live
in `nix/modules/neovim.nix`. Rebuild/switch after editing managed files. Parser
installation is disabled at runtime because Nix supplies the compiled parsers.
The pinned LSP plugin still supports the existing setup API and emits its upstream
deprecation notice. Migrating that API and the rewritten Tree-sitter API can be
done separately from this portability change.

Clipboard forwarding on headless boxes depends on your terminal's OSC 52 support;
test it over your usual SSH connection. macOS uses its native clipboard support.

## Updates and rollback

Update the main tools independently from the compatibility-pinned editor:

```sh
nix flake update nixpkgs home-manager --flake "path:$PWD"
nix flake check "path:$PWD"
home-manager build --flake "path:$PWD#$dotfiles_profile"
home-manager switch --flake "path:$PWD#$dotfiles_profile"
```

Update `nixpkgs-editor` separately when deliberately upgrading the editor stack.
Keep previous generations until the new one has been tested:

```sh
home-manager generations
```

To restore one, run the `activate` script inside its listed store directory:
`/nix/store/<previous-home-manager-generation>/activate`. This restores managed
configuration and packages, not application state. For the initial migration
there is no previous Home Manager generation: keep the backup above so you can
restore those original files. Avoid deleting old generations or garbage-collecting
the store until you are happy with the migration.
