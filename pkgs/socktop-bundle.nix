{ stdenv, rustPlatform, fetchFromGitHub, pkg-config, libdrm }:

let
  socktop = rustPlatform.buildRustPackage {
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
stdenv.mkDerivation {
  pname = "socktop-bundle";
  version = "master";
  buildInputs = [ socktop ];
  installPhase = ''
    mkdir -p $out/bin
    cp ${socktop}/bin/socktop $out/bin/
    cp ${socktop}/bin/socktop_agent $out/bin/
  '';
}
