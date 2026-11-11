# The released binaries, installed as released. Source builds: pkgs.herdr-core
# in nixpkgs. The release workflow writes nix/pins.json into the tagged commit.
{
  description = "herdr-core (hc), from the signed release archives";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs }:
    let
      pins = builtins.fromJSON (builtins.readFile ./nix/pins.json);
      forAll = f: nixpkgs.lib.genAttrs (builtins.attrNames pins.assets) (system: f nixpkgs.legacyPackages.${system});
      package =
        pkgs:
        let
          asset = pins.assets.${pkgs.stdenvNoCC.hostPlatform.system};
        in
        pkgs.stdenvNoCC.mkDerivation {
          pname = "herdr-core";
          inherit (pins) version;
          src = pkgs.fetchurl {
            url = "https://releases.herdr.dev/core/${pins.version}/${asset.name}";
            inherit (asset) hash;
          };
          sourceRoot = ".";
          # Linux is static and hc tells builds apart by their build id; the
          # macOS bundle is signed. Byte for byte, both.
          dontFixup = true;
          # macOS privacy grants belong to Herdr Core.app, so the commands link
          # into the bundle, as the installer makes them.
          installPhase = ''
            runHook preInstall
            install -Dm644 LICENSE THIRD-PARTY-NOTICES -t $out/share/licenses/herdr-core
          ''
          + (
            if pkgs.stdenvNoCC.hostPlatform.isDarwin then
              ''
                mkdir -p $out/Applications $out/bin
                cp -R "Herdr Core.app" $out/Applications/
                ln -s "$out/Applications/Herdr Core.app/Contents/MacOS/herdr-core" $out/bin/herdr-core
              ''
            else
              ''
                install -Dm755 herdr-core $out/bin/herdr-core
              ''
          )
          + ''
            ln -s herdr-core $out/bin/hc
            runHook postInstall
          '';
          meta = {
            description = "Terminal runtime for coding agents, from the signed release archives";
            homepage = "https://github.com/herdrdev/herdr-core";
            license = pkgs.lib.licenses.asl20;
            platforms = builtins.attrNames pins.assets;
            mainProgram = "hc";
            sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
          };
        };
    in
    {
      packages = forAll (pkgs: rec {
        herdr-core = package pkgs;
        default = herdr-core;
      });
      checks = forAll (pkgs: { herdr-core = self.packages.${pkgs.stdenvNoCC.hostPlatform.system}.default; });
    };
}
