{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";

    poetry2nix.url = "github:nix-community/poetry2nix";
    poetry2nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-trusted-public-keys =
      "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = { self, nixpkgs, devenv, systems, poetry2nix, ... }@inputs:
    let forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in {
      packages = forEachSystem (system: {
        devenv-up = self.devShells.${system}.default.config.procfileScript;
      });

      devShells = forEachSystem (system:
        let
          pkgs =
            nixpkgs.legacyPackages.${system}.extend poetry2nix.overlays.default;
          keymap-drawer = pkgs.poetry2nix.mkPoetryApplication rec {
            pname = "keymap-drawer";
            version = "0.18.1";
            preferWheels = true;
            projectDir = pkgs.fetchFromGitHub {
              owner = "caksoylar";
              repo = "keymap-drawer";
              rev = "8e773126a80cd140eb059ee77300208e1941c6b1";
              sha256 = "sha256-hVoA4ITBqlB+TqvI/qf23L6KFLPLFGRsdYwy6IOPk/k=";
            };
          };
          yq = nixpkgs.lib.getExe pkgs.yq-go;
        in {
          default = devenv.lib.mkShell {
            inherit inputs pkgs;
            modules = [{
              packages = [ keymap-drawer ];

              scripts.parse.exec = ''
                keymap_dir=./config
                for file in "$keymap_dir"/*.keymap; do
                  name="$(basename --suffix=".keymap" "$file")"
                  config="$keymap_dir/$name.yaml"

                  echo "found keymap $name"

                  [ -f "$config" ] && rm "$config"

                  keymap -c "$keymap_dir/keymap_drawer.yaml" parse -z "$file" > "$config"
                done
              '';

              scripts.draw.exec = ''
                set +e 
                img_out=./img
                keymap_dir=./config

                for file in "$keymap_dir"/*.keymap; do
                  name="$(basename --suffix=".keymap" "$file")"
                  config="$keymap_dir/$name.yaml"
                  echo "found keymap config $config"
                  
                  [ -f "$img_out/$name.svg" ] && rm "$img_out/$name.svg"
                  keymap -c "$keymap_dir/keymap_drawer.yaml" draw "$config" > "$img_out/$name.svg"

                  layers=$(${yq} '.layers | keys | .[]' "$config")
                  for layer in $layers; do
                    [ -f "$img_out/$name_$layer.svg" ] && rm "$img_out/$name_$layer.svg"
                    keymap -c "$keymap_dir/keymap_drawer.yaml" draw "$config" --select-layers "$layer" > "$img_out/$name_$layer.svg"
                  done
                done
              '';
            }];
          };
        });
    };
}
