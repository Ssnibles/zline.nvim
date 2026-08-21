{ lib, buildVimPlugin }:

buildVimPlugin {
  pname = "zline-nvim";
  version = "0.1.0";
  src = ./.;
}
