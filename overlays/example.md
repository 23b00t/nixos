# Example Nixpkgs overlay to workaround a broken package

```nix
{
  nixpkgs.overlays = [
    (final: prev: {
      # Replace problematic hyde-ipc with a dummy that notifies user it's disabled
      hyde-ipc = prev.runCommand "hyde-ipc-dummy" { } ''
        mkdir -p $out/bin
        echo "echo hyde-ipc is disabled" > $out/bin/hyde-ipc
        chmod +x $out/bin/hyde-ipc
      '';
    })
  ];
  # OR:
  nixpkgs.overlays = [
    (final: prev: {
      hyde-ipc =
        (import (fetchTarball {
          url = "https://github.com/NixOS/nixpkgs/archive/<ALT_COMMIT>.tar.gz";
        }) { system = prev.system; }).hyde-ipc;
    })
  ];
}
```
