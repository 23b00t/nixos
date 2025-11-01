{
  pkgs,
  ...
}:
{
  imports = [
    ./shared.nix
  ];

  home.username = "nvim";
  home.homeDirectory = "/home/nvim";

  home.sessionVariables.LANG = "en_US.UTF-8";

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withNodeJs = true;
    withPython3 = true;
    extraPackages = with pkgs; [
      python3
      fd
      unzip

      gcc
      gnumake

      nodejs
      rustc
      cargo
      rust-analyzer
      watchexec

      lua-language-server
      nixfmt

      watchman
    ];
  };
  home.sessionVariables = {
    MASON_DIR = "$HOME/.local/share/nvim/mason";
  };

  # direnv
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  home.stateVersion = "25.05";
}
