{ ... }:
{
  hydenix.hm = {
    enable = true;
    editors = {
      vscode.enable = false;
      default = "nvim"; # default text editor
    };
    git.enable = false;
    shell.enable = false;
    terminals.enable = false;
  };
}
