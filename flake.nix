{
  description = "xescure/ci self-test";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nix2container = {
      url = "github:nlewo/nix2container";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, nix2container, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      n2c = nix2container.packages.${system}.nix2container;
    in
    {
      packages.${system} = {
        inherit (pkgs) hello;
        fixture-image = n2c.buildImage {
          name = "ghcr.io/xescure/ci-fixture";
          layers = [ (n2c.buildLayer { deps = [ pkgs.hello ]; }) ];
          config.Entrypoint = [ "${pkgs.hello}/bin/hello" ];
        };
      };

      checks.${system} = {
        hello = pkgs.runCommand "ci-check-hello" { } "${pkgs.hello}/bin/hello >$out";
        userns = pkgs.runCommand "ci-check-userns" { nativeBuildInputs = [ pkgs.bubblewrap ]; } ''
          bwrap --unshare-user --ro-bind / / true
          touch $out
        '';
      };
    };
}
