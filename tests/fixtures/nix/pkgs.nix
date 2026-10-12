{
  description = "x";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs }:
    let
      pkgs = import nixpkgs {
        system = "aarch64-darwin";
      };
      names = [
        "a"
        "b"
      ];
      script = ''
        echo multi
        echo line
      '';
      f = x:
        if x > 1
        then x
        else 1;
    in
    {
      packages.default = pkgs.hello;
      inherit names script f;
    };
}
