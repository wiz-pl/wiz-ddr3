# nextpnr's chip databases for the two dies an Arty A7 can carry: xc7a50t (which
# nextpnr also uses for the xc7a35t, the same die) and xc7a100t. openXC7's
# nextpnr-xilinx-chipdb.artix7 builds every Artix-7 die (xc7a200t too, the largest);
# this is the same recipe (openXC7 toolchain-nix, nix/nextpnr-chipdb.nix) for two.
{ stdenv, python3, nextpnr, prjxray-db }:
stdenv.mkDerivation {
  pname = "arty-chipdb";
  version = nextpnr.version;
  dontUnpack = true;
  dontInstall = true;
  nativeBuildInputs = [ python3 ];
  buildPhase = ''
    mkdir -p $out
    for die in xc7a50t xc7a100t; do
      python3 ${nextpnr}/share/nextpnr/himbaechel/uarch/xilinx/gen/xilinx_gen.py \
        --xray ${prjxray-db}/artix7 --device $die --bba $die.bba
      ${nextpnr}/bin/bbasm -l $die.bba $out/chipdb-$die.bin
      rm -f $die.bba
    done
    # the part names nextpnr is given (speed grade stripped)
    ln -s chipdb-xc7a50t.bin $out/xc7a35tcsg324.bin
    ln -s chipdb-xc7a50t.bin $out/xc7a35ticsg324.bin
    ln -s chipdb-xc7a100t.bin $out/xc7a100tcsg324.bin
  '';
}
