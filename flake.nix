{
  description = "xescure/ci: shared CI for xescure's Nix projects. Its checks and fixture image are nix-image.yml's self-test.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = {
        inherit (pkgs) hello;
        fixture-image = pkgs.dockerTools.buildLayeredImage {
          name = "ci-fixture";
          config.Entrypoint = [ "${pkgs.hello}/bin/hello" ];
        };
      };

      checks.${system} = {
        hello = pkgs.runCommand "ci-check-hello" { } "${pkgs.hello}/bin/hello >$out";
        # What the bwrap input is for: a user namespace opened inside the build sandbox.
        userns = pkgs.runCommand "ci-check-userns" { nativeBuildInputs = [ pkgs.bubblewrap ]; } ''
          bwrap --unshare-user --ro-bind / / true
          touch $out
        '';
      };
    };
}
