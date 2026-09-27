{
  description = "Isaac's portable Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Upgrade the Neovim 0.11 / legacy Tree-sitter stack separately.
    nixpkgs-editor.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-editor,
      home-manager,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkHome =
        {
          system,
          profile,
          profileName,
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs.editorPkgs = nixpkgs-editor.legacyPackages.${system};
          modules = [
            ./home.nix
            profile
            {
              xdg.configFile."just/config.just".text = ''
                # Managed by Home Manager; selected by the activated flake profile.
                home_profile := ${builtins.toJSON profileName}
              '';
            }
          ];
        };
      homes = nixpkgs.lib.mapAttrs (profileName: args: mkHome (args // { inherit profileName; })) {
        macbook = {
          system = "aarch64-darwin";
          profile = ./nix/profiles/macbook.nix;
        };
        linux-user = {
          system = "x86_64-linux";
          profile = ./nix/profiles/linux-user.nix;
        };
        applied = {
          system = "x86_64-linux";
          profile = ./nix/profiles/applied.nix;
        };
        brix-root = {
          system = "x86_64-linux";
          profile = ./nix/profiles/brix-root.nix;
        };
        linux-arm = {
          system = "aarch64-linux";
          profile = ./nix/profiles/linux-user.nix;
        };
      };
      homeForSystem = {
        aarch64-darwin = homes.macbook;
        x86_64-linux = homes.brix-root;
        aarch64-linux = homes.linux-arm;
      };
    in
    {
      homeConfigurations = homes;
      lib.mkHome = mkHome;
      # Bootstrap the CLI from the same lockfile as the configuration.
      packages = forAllSystems (system: {
        home-manager = home-manager.packages.${system}.home-manager;
      });
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
      checks = forAllSystems (
        system:
        import ./nix/checks.nix {
          pkgs = nixpkgs.legacyPackages.${system};
          home = homeForSystem.${system};
        }
      );
    };
}
