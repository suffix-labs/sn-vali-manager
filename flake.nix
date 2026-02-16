{
  description = "StarkNet Multi-Validator Node Manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Node.js for claim-rewards script
            nodejs_22
            nodePackages.npm

            # Kubernetes tools
            kubectl
            kubernetes-helm
            kustomize

            # Useful utilities
            jq
            yq-go

            # GitHub CLI for PR operations
            gh
          ];

          shellHook = ''
            echo "StarkNet Validator Manager Dev Shell"
            echo "===================================="
            echo "Node.js: $(node --version)"
            echo "kubectl: $(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion')"
            echo ""
            echo "Quick commands:"
            echo "  cd scripts/claim-rewards && npm install  # Setup claim script"
            echo "  npm run claim:dry-run                    # Test reward claiming"
            echo "  ./deploy.sh                              # Deploy to k8s"
            echo ""
          '';
        };

        # Package the claim-rewards script
        packages.claim-rewards = pkgs.buildNpmPackage {
          pname = "starknet-claim-rewards";
          version = "1.0.0";
          src = ./scripts/claim-rewards;
          npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Update after first build
          dontNpmBuild = true;
          installPhase = ''
            mkdir -p $out/bin $out/lib
            cp -r node_modules $out/lib/
            cp *.js $out/lib/
            cat > $out/bin/claim-rewards <<EOF
            #!${pkgs.bash}/bin/bash
            exec ${pkgs.nodejs_22}/bin/node $out/lib/claim-rewards.js "\$@"
            EOF
            chmod +x $out/bin/claim-rewards
          '';
        };
      }
    );
}
