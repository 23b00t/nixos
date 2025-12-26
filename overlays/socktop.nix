self: super: {
  socktop = self.rustPlatform.buildRustPackage {
    pname = "socktop";
    version = "master";
    src = self.fetchFromGitHub {
      owner = "jasonwitty";
      repo = "socktop";
      rev = "master";
      sha256 = "sha256-y+hgBeK88cVIxT+HxoWiq/JrvmPmXBNWhFhHH647jic=";
    };
    cargoHash = "sha256-570Eiu03c66RFB3Psy9UC/ab30GbrXg+f/dpOlLfGKo=";
    nativeBuildInputs = [ self.pkg-config ];
    buildInputs = [ self.libdrm ];
  };
}
