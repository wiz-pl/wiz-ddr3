{
  description = "A DDR3 controller in Wiz's HDL for the Arty A7 (openXC7 flow)";

  inputs = {
    # The Wiz toolchain (wiz, grail, the standard library). flake.lock pins the commit.
    wiz.url = "github:wiz-pl/wiz/agent/hdl-prim";
    nixpkgs.follows = "wiz/nixpkgs";
    # openXC7: nextpnr (himbaechel xilinx uarch, `nextpnr-xilinx` shim), its Artix-7
    # chip databases, Project X-Ray (fasm2frames, xc7frames2bit) and prjxray-db.
    # It keeps its own nixpkgs: its expressions are tested against that one.
    openxc7.url = "github:openXC7/toolchain-nix";
  };

  outputs = { self, nixpkgs, wiz, openxc7 }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in {
      packages = forAll (system: pkgs:
        let x = openxc7.packages.${system}; in {
          inherit (x) nextpnr prjxray prjxray-db fasm;
          chipdb = pkgs.callPackage ./nix/chipdb.nix { inherit (x) nextpnr prjxray-db; };
        });
      devShells = forAll (system: pkgs:
        let
          x = openxc7.packages.${system};
          chipdb = self.packages.${system}.chipdb;
          # fasm2frames runs on openXC7's Python 3.12 (fasm's parser is a C++ extension
          # built for it): its modules come from openXC7's nixpkgs.
          xpkgs = openxc7.inputs.nixpkgs.legacyPackages.${system};
          py = xpkgs.python312.withPackages (p: [ p.pyyaml p.simplejson p.intervaltree p.textx p.cython p.setuptools ]);
        in {
          default = pkgs.mkShell {
            packages = [
              wiz.packages.${system}.wiz   # wiz and grail
              pkgs.yosys                   # synthesis (synth_xilinx)
              x.nextpnr                    # nextpnr-xilinx (shim) / nextpnr-himbaechel
              x.prjxray                    # fasm2frames, xc7frames2bit
              x.fasm                       # the FASM parser fasm2frames imports
              pkgs.iverilog                # simulation of the emitted Verilog
            ];
            # The variables openXC7's own devshell exports, which the `arty` driver reads.
            ARTY_CHIPDB = "${chipdb}";
            PRJXRAY_DB_DIR = "${x.prjxray-db}";
            PRJXRAY_PYTHON_DIR = "${x.prjxray}/usr/share/python3";
            # fasm2frames' imports: prjxray, fasm and their dependencies
            PYTHONPATH = "${x.prjxray}/usr/share/python3:${x.fasm}/${xpkgs.python312.sitePackages}:${py}/${py.sitePackages}";
          };
        });
    };
}
