let
  # Central VM registry used across host, home-manager scripts and helper tools.
  # Each VM entry has the following fields:
  #   name        : long name without "-vm" suffix (e.g. "nvim")
  #   short       : short alias used in CLI tools (e.g. "n")
  #   ip          : IPv4 address on the 10.0.0.0/24 network
  #   autostart   : whether the VM should autostart via microvm.host
  #   nat         : whether the VM should be included in networking.nat.internalIPs
  #   sshKeyName  : basename of SSH key in ~/.ssh
  #   extraSSH    : extra SSH matchOptions for home.ssh (may be [])
  vms = [
    {
      name = "nvim";
      short = "n";
      ip = "10.0.0.1";
      autostart = true;
      nat = true;
      sshKeyName = "nvim-vm";
      extraSSH = [
        "RemoteForward 4713 localhost:4713"
      ];
    }
    {
      name = "chat";
      short = "c";
      ip = "10.0.0.2";
      autostart = true;
      nat = true;
      sshKeyName = "chat-vm";
    }
    # {
    #   name = "test";
    #   short = "t";
    #   ip = "10.0.0.3";
    #   autostart = false;
    #   nat = true;
    #   sshKeyName = "test-vm";
    # }
    {
      name = "music";
      short = "m";
      ip = "10.0.0.4";
      autostart = true;
      nat = true;
      sshKeyName = "music-vm";
      extraSSH = [
        "RemoteForward 4713 localhost:4713"
      ];
    }
    {
      name = "net";
      short = "net";
      ip = "10.0.0.5";
      autostart = true;
      nat = true;
      sshKeyName = "net-vm";
    }
    {
      name = "net-private";
      short = "np";
      ip = "10.0.0.6";
      autostart = false;
      nat = true;
      sshKeyName = "net-private-vm";
    }
    {
      name = "wine";
      short = "w";
      ip = "10.0.0.7";
      autostart = false;
      nat = true;
      sshKeyName = "wine-vm";
    }
    {
      name = "kali";
      short = "k";
      ip = "10.0.0.8";
      autostart = false;
      nat = true;
      sshKeyName = "kali-vm";
    }
    {
      name = "office";
      short = "o";
      ip = "10.0.0.9";
      autostart = false;
      nat = false;
      sshKeyName = "office-vm";
    }
    {
      name = "vault";
      short = "v";
      ip = "10.0.0.10";
      autostart = false;
      nat = false;
      sshKeyName = "vault-vm";
    }
    {
      name = "irc";
      short = "i";
      ip = "10.0.0.11";
      autostart = true;
      nat = false;
      sshKeyName = "irc-vm";
    }
    {
      name = "steam";
      short = "s";
      ip = "10.0.0.12";
      autostart = false;
      nat = true;
      sshKeyName = "steam-vm";
    }
    {
      name = "godot";
      short = "g";
      ip = "10.0.0.13";
      autostart = false;
      nat = true;
      sshKeyName = "godot-vm";
    }
    {
      name = "mirage";
      short = "mi";
      ip = "10.0.0.14";
      autostart = false;
      nat = true;
      sshKeyName = "mirage-vm";
    }
    {
      name = "php";
      short = "p";
      ip = "10.0.0.15";
      autostart = false;
      nat = true;
      sshKeyName = "php-vm";
    }
    {
      name = "ruby";
      short = "r";
      ip = "10.0.0.16";
      autostart = false;
      nat = true;
      sshKeyName = "ruby-vm";
    }
    {
      name = "sys-net";
      short = "sn";
      ip = "10.0.0.253";
      autostart = true;
      nat = false;
      sshKeyName = "sys-net-vm";
    }
  ];

  byName = builtins.listToAttrs (
    map (vm: {
      name = vm.name;
      value = vm;
    }) vms
  );

  byShort = builtins.listToAttrs (
    map (vm: {
      name = vm.short;
      value = vm;
    }) (builtins.filter (vm: vm.short != null) vms)
  );

  natIPs = map (vm: vm.ip) (builtins.filter (vm: vm.nat or false) vms);

  autostartNames = map (vm: vm.name) (builtins.filter (vm: vm.autostart or false) vms);

  globalExtraSSH = [ "RemoteForward /tmp/ssh_dbus.sock /run/user/1000/vm-session-bus.sock" ];
in
{
  inherit
    vms
    byName
    byShort
    natIPs
    autostartNames
    globalExtraSSH
    ;
}
