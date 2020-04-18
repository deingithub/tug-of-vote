with import <nixpkgs> {};
crystal.buildCrystalPackage rec {
  version = "0.1.0";
  pname = "TugOfVote";
  src = ./.;

  shardsFile = ./shards.nix;
  crystalBinaries.TugOfVote.src = "src/TugOfVote.cr";

  buildInputs = [ sqlite-interactive.dev ];
}
