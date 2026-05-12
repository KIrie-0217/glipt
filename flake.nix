{
  description = "glipt — A script runner for Gleam";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        glipt = pkgs.stdenv.mkDerivation {
          pname = "glipt";
          version = "1.1.1";
          src = ./.;

          nativeBuildInputs = [
            pkgs.gleam
            pkgs.erlang
            pkgs.rebar3
          ];

          buildPhase = ''
            export HOME=$TMPDIR
            gleam export erlang-shipment
          '';

          installPhase = ''
            mkdir -p $out/bin $out/lib/glipt
            cp -r build/erlang-shipment/* $out/lib/glipt/
            cat > $out/bin/glipt <<'WRAPPER'
            #!/bin/sh
            exec ERLPATH -pa LIBDIR/*/ebin -noshell -eval "glipt@@main:run(glipt)" -extra "$@"
            WRAPPER
            substituteInPlace $out/bin/glipt \
              --replace ERLPATH "${pkgs.erlang}/bin/erl" \
              --replace LIBDIR "$out/lib/glipt"
            chmod +x $out/bin/glipt
          '';

          meta = with pkgs.lib; {
            description = "A script runner for Gleam";
            license = licenses.mit;
            mainProgram = "glipt";
          };
        };
      in
      {
        packages.default = glipt;

        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.gleam
            pkgs.erlang
            pkgs.rebar3
          ];
        };
      }
    );
}
