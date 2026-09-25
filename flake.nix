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
        { system, profile }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs.editorPkgs = nixpkgs-editor.legacyPackages.${system};
          modules = [
            ./home.nix
            profile
          ];
        };
      homes = {
        macbook = mkHome {
          system = "aarch64-darwin";
          profile = ./nix/profiles/macbook.nix;
        };
        linux-user = mkHome {
          system = "x86_64-linux";
          profile = ./nix/profiles/linux-user.nix;
        };
        applied = mkHome {
          system = "x86_64-linux";
          profile = ./nix/profiles/applied.nix;
        };
        brix-root = mkHome {
          system = "x86_64-linux";
          profile = ./nix/profiles/brix-root.nix;
        };
        linux-arm = mkHome {
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
