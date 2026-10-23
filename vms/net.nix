# net: browsing (zen as the default browser, firefox with language packs).
{ inputs, ... }:
{
  imports = [ (inputs.nox.lib.vms + "/modules/zen-firefox.nix") ];
  _module.args.zen-browser = inputs.zen-browser;

  services.common-config.browser = "zen.desktop";

  programs.firefox = {
    enable = true;
    languagePacks = [
      "de"
      "en-US"
    ];
  };
}
