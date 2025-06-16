{ config, pkgs, ...}: {
  programs.vim = {
    enable = true;
    settings = {
      expandtab = true;     # Use spaces instead of tabs
      shiftwidth = 2;       # Indent by 2 spaces
      tabstop = 2;          # Display tabs as 2 spaces
      number = true;        # Show line numbers
    };
    extraConfig = ''
      " Deactivate swap files
      set noswapfile

      " Use system clipboard (Wayland)
      set clipboard=unnamedplus

      " Keep visual selection after indenting
      vnoremap < <gv
      vnoremap > >gv
    '';
  };
}
