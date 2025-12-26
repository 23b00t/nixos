{ rustPlatform, fetchFromGitHub, pkg-config, libdrm, stdenv }:

let
  socktopFull = rustPlatform.buildRustPackage {
    pname = "socktop";
    version = "master";
    src = fetchFromGitHub {
      owner = "jasonwitty";
      repo = "socktop";
      rev = "master";
      sha256 = "sha256-y+hgBeK88cVIxT+HxoWiq/JrvmPmXBNWhFhHH647jic=";
    };
    cargoHash = "sha256-570Eiu03c66RFB3Psy9UC/ab30GbrXg+f/dpOlLfGKo=";
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ libdrm ];
  };
in
{
  socktop = stdenv.mkDerivation {
    pname = "socktop";
    version = "master";
    dontUnpack = true;
    buildInputs = [ socktopFull ];
    installPhase = ''
      mkdir -p $out/bin
      cp ${socktopFull}/bin/socktop $out/bin/
    '';
  };

  socktop_agent = stdenv.mkDerivation {
    pname = "socktop-agent";
    version = "master";
    dontUnpack = true;
    buildInputs = [ socktopFull ];
    installPhase = ''
      mkdir -p $out/bin
      cp ${socktopFull}/bin/socktop_agent $out/bin/
    '';
  };
}
