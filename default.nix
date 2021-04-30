with import (builtins.fetchTarball {
  url = "https://github.com/NixOS/nixpkgs/tarball/befefe6f3f202c9945e9e8370422e0837339e7ae";
  sha256 = "17xpwz0fvz8kwniig7mkqi2grrppny4d4pl5dg28p49ahzmhp7r4";
}) {};

crystal.buildCrystalPackage rec {
  version = "0.1.0";
  pname = "TugOfVote";
  src = ./.;

  shardsFile = ./shards.nix;
  crystalBinaries.TugOfVote.src = "src/TugOfVote.cr";
  crystalBinaries.TugOfVote.options = [];

  buildInputs = [ sqlite-interactive.dev openssl.dev ];
}
