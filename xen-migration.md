# Xen Migration

## Allgemeine Ziele, Ethik etc.

- Ein hoch erweiterbares und customizable System, mit guter UI/UX, mit möglichst hoher Sicherheit (wichtigkeit absteigend); also in Abgrenzung zu QubesOS wo Sicherheit an erster Stelle steht (für uns aber trozdem ein wichtiges Ziel, nur nicht das Höchste).
- Eine NixOS Flavour OS (siehe v4 und v5) entwickeln. Also Tooling das auf viel verschiedener Hardware geht, eine gut vorkonfigurierte dom0, VMs als Templates/ Vorschläge, die über den Installer ausgewählt werden können, dann aber auch noch manuell angepasst werden können etc.
- Der microvm code bleibt mit dem upstream sync bar (kann aber vlt. für unsere Zwecke später noch gekürzt werden).
- Außer dem Microvm Code kommt alles zum User in ein Repo, wir wollen so wenig wie möglich vorm User verstecken, der User ist autonom und wir ermächtigen ihn mit den Tools zu arbeiten.
- Wir haben aber auch prebuild Workflows die für unerfahrene Nutzer funktionieren, wenn sie bereit sind ein bisschen docs zu lesen, sich einen remote git Account zu machen etc.
- Alles wird auf Xen migriert, qubesOS ähnliches Zielsystem, nur eben mit nixos, microvm.nix, wprs, niri als Core Technologien.

## Erkenntnisse und Empfehlungen (Stand 2026-10-05, nach v1 auf dem hp)

### Feste Invarianten (trotz "UX vor Sicherheit")

- In dom0 läuft kein Browser und kein Netzwerk-Client. Die Testphase-Extras in `machines/hp/dev-access.nix` (`google-chrome`, `claude-code`, SSH aus dem LAN, NOPASSWD-sudo) fliegen spätestens mit sys-net raus.
- dom0 hat kein allgemeines Internet (ab v2 gar keins, Updates über die Builder-VM).
- Datenflüsse zwischen VMs gibt es nur explizit (Copy, Clipboard, USB-Zuordnung, Firewall-Regeln pro Paar).

### Reihenfolge und Risiken

- **XMG früher testen:** ein reiner dom0-Smoke-Test auf dem XMG (Xen-Boot-Eintrag neben dem normalen, ohne VMs) schon in v2/v3, nicht erst in v4. Das Touchpad auf dem hp hat gezeigt, dass Hardware den Plan kippen kann; größtes Risiko ist die NVIDIA-dGPU (amdgpu/Grafik in dom0, später Passthrough). Prüfen: Boot, niri, Eingabegeräte, WLAN, Suspend, und an welchen USB-Controllern Tastatur und Maus hängen (bestimmt die sys-usb-Ausnahme, siehe v2.6).
- **Builder-VM ist in v2 vorgezogen** (v2.4), weil sie zwei Probleme auf einmal löst: dom0 ohne Netz und dom0-RAM (die Evaluierung braucht heute ~6,6 GB in dom0).
- **Keine NixOS-Specialisations auf Xen-Hosts:** jede wertet Host und alle MicroVMs erneut aus und sprengt den dom0-RAM (Erfahrung mit `pv-dom0`).
- **Änderungen, die Dienste in dom0 entfernen, mit `nixos-rebuild boot` anwenden:** z. B. stoppt ein `switch` beim Entfernen von `xendomains` alle VMs.

### Xen-spezifische Lehren aus v1

- **PVH-dom0 bleibt das Ziel.** Bei Hardwareproblemen in dom0 (fehlende Interrupts, tote Eingabegeräte) zuerst PV-dom0 probieren (`dom0=pv`). Details zum Touchpad-Fall in `README.md` ("Known hardware issues").
- `xendomains` muss auf jedem Xen-Host aus sein, solange die `microvm@`-Dienste die Domains verwalten (sonst 90 s Hänger beim Shutdown). Gehört beim v4-Refactor in die gemeinsame dom0-Config.
- `xl list -l` blockiert auf dem hp sehr lange (nvim: >10 min, abgebrochen; vault: kam nach einigen Minuten zurück) und hält dabei die Userdata-Sperre der Domain; so lange blockieren `xl mem-max`/`mem-set` für diese Domain und laufen danach verspätet. Ursache unbekannt. Bis dahin: `xl list -l` nicht nutzen, xl-Aufrufe in Scripts immer mit `timeout`. Wichtig für den RAM-Daemon (v2.3).
- `/var/lib/xen/userdata-*` sammelt Dateien alter Domain-IDs über Reboots an (harmlos, beim Aufräumen im Blick behalten).

### microvm.nix-Fork

- Den Xen-Runner weiter in sich geschlossen halten und bestehende microvm-Optionen nutzen (`mem`, `hotplugMem`, `balloon`, `devices`, `storeDisk`), neue nur unter `microvm.xen.*`. Dann bleibt der Fork synchron, und ein späterer upstream-PR ist realistisch.

## v2

Ziel: dom0 ohne Netz und ohne Hardware außer GPU/Input, Netz und USB in Driver-Domains, VMs mit gruppierten Template-Stores und dynamischem RAM. Testsystem bleibt der hp (Hardware siehe `README.md` "Test system").

### Ausgangslage und harte Fakten

- **PCI-Passthrough geht bei PVH-dom0 nur in HVM-Gäste** (Xen 4.22 Changelog: "PCI passthrough for HVM domUs when dom0 is PVH"). PVH-domUs können gar kein Passthrough. Deshalb müssen **sys-net und sys-usb HVM** sein (wie bei Qubes). PV-domUs sind mit PVH-dom0 keine Alternative für Passthrough.
- IOMMU auf dem hp aktiv (AMD-Vi, Interrupt-Remapping), `pciback` vorhanden.
- Kein virtiofs auf Xen x86. Für den Store gibt es nur: Block-Device (blkback, wie heute erofs), 9pfs (Dateiserver in dom0: `xen-9pfsd` oder qemu, langsam, mehr Angriffsfläche in dom0), oder Netzwerk-Protokolle (nicht sinnvoll).
- Xen hat kein KSM: geteilte Stores sparen Platte und Build-Zeit, **nicht RAM** (jeder Gast hat seinen eigenen Page-Cache).
- Xen vergrößert Gäste nicht selbst. "Bei Bedarf mehr RAM" braucht einen Agenten im Gast und einen Daemon in dom0 (Qubes: qmemman).
- Begriff: In Xen heißt "Stubdomain" eine Mini-Domain, die das Device-Model (qemu) eines HVM-Gasts kapselt. sys-net/sys-usb/sys-firewall sind **Driver-Domains**. Die Store-Gruppe dafür heißt hier `sys`.

### Entscheidungen (2026-10-05)

| Thema | Entscheidung |
|---|---|
| dom0-Netz | dom0 bekommt **kein** Netz. Builds und Evaluierung laufen in der Builder-VM, dom0 holt nur fertige Closures. Ein vif mit Whitelist höchstens als kurze Zwischenlösung. |
| GUI/Admin-Pfad | v2: **zwei vifs pro VM** (Admin-vif an dom0, Uplink-vif an sys-net). Langfristig GUI und Admin über **vchan** statt Netz (siehe "Nach v2"). |
| USB/Webcam | Direkt **sys-usb** (HVM, alle USB-Controller per Passthrough), Webcam per USB/IP in die chat-VM, USB-Tastatur/-Maus per Input-Proxy zurück an dom0. Kein Zwischenschritt über dom0. |
| Store-Gruppen | `sys`: sys-net, sys-usb (später sys-firewall) · `dev`: nvim, php, ruby, godot, mirage, yazelix, kali, nix, test · `desktop`: office, net, music, vault, irc · `prop`: chat, wine (und Steam) · **coding** und **builder**: standalone |
| RW-Store | Das bestehende `persistent-store-overlay.nix` bleibt die Lösung für Laufzeit-Installationen (funktioniert auf dem XMG). coding nutzt es als Standalone-VM, sonst kaum gebraucht. |
| Gasttypen | PVH Standard, HVM für Driver-Domains und später Steam/Tails, PV nur als billige Option. |

### Arbeitspakete (Reihenfolge = Abhängigkeiten)

#### v2.1 microvm.nix: Xen-Fähigkeiten (Fork)

Alles im Xen-Runner und im Host-Modul, möglichst über **bestehende** microvm-Optionen, damit der Fork mit upstream synchron bleibt.

- **Gasttyp:** neue Option `microvm.xen.type = "pvh" | "hvm" | "pv"` (Default `pvh`) → `type=` im xl.cfg.
  - HVM: Device-Model qemu-xen in dom0 (läuft schon als Disk-Backend). Direktes Booten mit `kernel`/`ramdisk`/`cmdline` funktioniert auch bei HVM, der microvm-Ansatz bleibt. Gast-Kernel braucht PV-Treiber (blkfront/netfront, im NixOS-Standardkernel).
  - Stubdomains für das Device-Model → v3 (Sicherheit, nicht Funktion).
  - **Umgesetzt 2026-10-05 (Fork `55d3b38`):** `microvm.xen.type` und `microvm.xen.qemuPackage` (Default `qemu_xen`). HVM: `bzImage` statt `vmlinux`, `device_model_override` auf qemu-xen, `vga = "none"`, vifs mit `type=vif` (kein emuliertes NIC).
  - **HVM-Disks ab `xvde`:** qemu-xen emuliert `xvda`–`xvdd` zusätzlich als IDE und kann das nicht read-only (`qemu-xen doesn't support read-only IDE disk drivers`). Neue Funktion `firstDiskIndex` in `lib/default.nix` verschiebt Store-Disk und Volumes bei HVM um 4 Buchstaben; Gast (`withDriveLetters`) und Runner nutzen dieselbe Funktion. Die Store-Disk mountet der Gast ohnehin per erofs-Label.
  - **Getestet auf dem hp:** HVM-Testdomain (vault-System, ohne Netz) bootet bis zum Login, Console-Log über `hvc0` geht, Ballooning per PoD geht (2047 ↔ 767), sauberer Shutdown beendet auch qemu. qemu braucht ~93 MB RSS in dom0 pro HVM-Gast (für das dom0-RAM-Budget).
  - **PV-Gäste sind auf AMD mit Gast-Kernel 6.18 kaputt:** Panic in `print_s5_reset_status_mmio` (liest FCH-MMIO bei `0xfed80…`, das ein PV-Gast nicht hat). Kernel-Bug, nicht unsere Config. PV bleibt als Option drin, ist aber auf dem hp nicht nutzbar (auf dem XMG mit Intel-CPU evtl. schon).
- **PCI-Passthrough:** bestehendes `microvm.devices` (`bus = "pci"`) → `pci = [ … ]` im xl.cfg; `throw`, wenn nicht `type = "hvm"`.
  - Host: `microvm-pci-devices@<vm>` bindet heute an `vfio-pci`; unter Xen stattdessen `xl pci-assignable-add` (bindet an `pciback`). Gerätelisten weiter aus `registry.nix` (`hardware.pci`).
  - **Umgesetzt 2026-10-05 (Fork `1c63ff6`):** Runner schreibt `pci = [ … ]`; `throw` bei PVH/PV (nur HVM), bei `bus = "usb"` (USB geht über sys-usb) und bei `memory < maxmem` (Passthrough verträgt kein Populate-on-Demand, also kein Ballooning beim Boot). `pci-devices.nix` erzeugt für Xen ein `pci-setup` mit `xl pci-assignable-add` (idempotent) statt vfio-pci.
  - **Getestet auf dem hp mit dem USB-Controller `03:00.3` (Kamera + Bluetooth) in einer HVM-Testdomain:** Controller kommt im Gast an, aber **MSI-X geht nicht**: qemu meldet `msi_msix_setup: Error: Mapping of MSI-X (err: 61 …)` (ENODATA), der Interrupt zählt 0, xHCI-Befehle brechen ab (`Command Aborted`). **Mit `pci=nomsi` im Gast (INTx/GSI) funktioniert alles:** Kamera als UVC-Gerät (`/dev/video0`), Bluetooth-Chip erkannt. Zurückgeben an dom0 mit `xl pci-assignable-remove -r` geht sauber (Treiber wieder `xhci_hcd`, Geräte wieder da) → der sys-usb-Fallback aus v2.6 ist machbar.
  - **Vorläufige Lösung:** Driver-Domains bekommen `boot.kernelParams = [ "pci=nomsi" ]`. INTx reicht für USB und WLAN; Performance prüfen. Ursache von ENODATA (MSI-X-Mapping bei PVH-dom0, laut Changelog sollte es gehen) bleibt offen.
- **Speicher:** nur bestehende microvm-Optionen, sie werden für Xen implementiert (heute `throw` im Runner). Abbildung nach der upstream-Bedeutung (bei qemu/cloud-hypervisor ist `mem` die Obergrenze, der Balloon nimmt davon weg):
  - `microvm.balloon = true` → Ballooning an.
  - `microvm.mem` → `maxmem` (Obergrenze).
  - `microvm.mem - microvm.initialBalloonMem` → `memory` (Start-RAM).
  - `microvm.hotplugMem`/`hotpluggedMem` (upstream: virtio-mem) → optional dieselbe Abbildung (`maxmem = mem + hotplugMem`, Start `= mem + hotpluggedMem`); nur eins von beiden zulassen, sonst `throw`.
  - `microvm.deflateOnOOM` hat bei Xen kein Gegenstück (virtio-balloon-Feature) → übernimmt der RAM-Daemon (v2.3), Warnung im Runner.
  - **Getestet 2026-10-05 auf dem hp (Gast-Kernel 6.18, `XEN_BALLOON=y`, `XEN_BALLOON_MEMORY_HOTPLUG=y`, Auto-Online):**
    - Boot mit `memory = 1024`, `maxmem = 2048` (PVH) bootet sauber, `xl mem-set` 2048 wächst, 768 schrumpft. Über `maxmem` lehnt libxl ab (`memory_dynamic_max must be <= memory_static_max`).
    - Laufende VM ohne `maxmem`: `xl mem-max` + `xl mem-set` vergrößert per Memory-Hotplug (nvim 4096 → 5120, `MemTotal` 4,0 → 5,06 GB), Schrumpfen gibt den RAM wirklich an Xen zurück (`free_memory` +2 GB).
    - **Folge fürs Design:** `memory`/`maxmem` im xl.cfg reichen; der Daemon bewegt sich nur zwischen beiden. `mem-max` zur Laufzeit ist der Notausgang, um über die Config-Grenze zu gehen.
  - **Umgesetzt 2026-10-05 (Fork `6b756ba`):** Abbildung wie oben im Xen-Runner, plus `setBalloonScript` → `microvm-balloon <size-mb>` (`xl mem-set <vm> (maxmem - size)`, mit `timeout`). Erster Nutzer: vault (`mem = 2048`, `balloon = true`, `initialBalloonMem = 1024`), läuft auf dem hp. `deflateOnOOM` ohne Warnung (Default `true` hätte bei jeder Balloon-VM gewarnt).
- **Netz-Backend pro Interface:** xen-spezifische Option (z. B. `microvm.xen.interfaceBackends.<id> = "sys-net-vm"`) → `backend=` im vif. Kein Eingriff ins upstream-Interface-Schema.
  - **Umgesetzt 2026-10-05 (Fork `820e412`):** `microvm.xen.interfaceBackends.<id> = "<domain>"` → `backend=` im vif (nur `type = "bridge"`, die Bridge lebt in der Driver-Domain; tap wirft einen Fehler). **Ohne `vifname`:** die upstream-Hotplug-Scripts (`set_mtu` in `xen-network-common.sh`) leiten die Frontend-Domid aus dem Standardnamen `vif<domid>.<devid>` ab und scheitern an umbenannten vifs. Firewall-Regeln in sys-net matchen also auf `vif*` bzw. Bridge-Ports, nicht auf eigene Namen.
- **Geteiltes Store-Image:** `microvm.storeDisk` muss auf ein fremdes (Gruppen-)Image zeigen dürfen; Disk mit `access=ro` (Xens Block-Script erlaubt mehrere Leser).
  - **Umgesetzt 2026-10-06 (Fork `cdf26a3`):** Image-Bau aus `store-disk.nix` nach `lib/store-disk.nix` verschoben und als `microvm.lib.buildStoreDisk { pkgs, type, erofsFlags, squashfsFlags, contents }` exportiert. Neue Option `microvm.storeDiskContents` (Default: toplevel + regInfo), `microvm.storeDisk` ist jetzt `mkDefault`. Gruppen-Image = `buildStoreDisk` über die `storeDiskContents` aller Mitglieder. Refactor ist neutral (vault-Image: gleicher drvPath wie vorher).
  - **Getestet (nur Build):** gemeinsames Image für vault + nvim (Test-Flake mit `extendModules`) (1,9 GB); beide xl.cfg zeigen auf dasselbe Image, beide toplevels und regInfos sind drin, kein Eval-Zyklus. Boot-Test beider Domains gleichzeitig steht aus.
- **Driver-Domain-Unterstützung im Gast:** Modul, das in sys-net/sys-usb `xl devd` startet (dort laufen dann die vif-Hotplug-Scripts) und die Xen-Tools bereitstellt.
  - **Umgesetzt 2026-10-05 (Fork `820e412`):** `microvm.xen.driverDomain = true` → `driver_domain = 1` im xl.cfg; im Gast: Module `xen-netback`, `xen-evtchn`, `xen-gntdev`, `xen-gntalloc`, `xen-privcmd`, `bridge`, `xenfs` auf `/proc/xen`, `/etc/xen/scripts`, Service `xendriverdomain` (`xl devd`, `LogsDirectory = "xen"`).
  - **Getestet auf dem hp:** Driver-Domain (vault-System, PVH) + Frontend (nvim-System) mit `backend=` auf eine Bridge in der Driver-Domain: vif erscheint dort (`vif19.0`), Ping 0 % Verlust, dom0 hat kein vif dafür. Harmlos im devd-Log: `libxl_cpu_bitmap_alloc: failed to retrieve the maximum number of cpus` (domU darf das nicht abfragen).
- Weitere Optionen, die sich lohnen: `vcpus`/`maxvcpus`, CPU-Pinning bzw. cpupools, credit2 `weight`/`cap` (UX, z. B. Steam), `on_crash`-Policy. `microvm.xen.extraConfig` bleibt als Notausgang.
  - **Umgesetzt 2026-10-06 (Fork, uncommitted):** `microvm.xen.maxvcpus` (Boot mit `microvm.vcpu`, Rest per `xl vcpu-set`; `throw` wenn kleiner als `vcpu`), `xen.cpus` (hartes Pinning), `xen.pool` (cpupool muss in dom0 existieren, Anlegen ist Host-Sache), `xen.weight` → `cpu_weight`, `xen.cap`, `xen.onCrash` = `destroy` | `preserve` | `coredump-destroy` (keine Restart-Aktionen, Neustart macht der systemd-Service). Alles `null`/Default → nichts im xl.cfg. Hinweis: Mit `panic=-1` in der cmdline rebootet ein Gast-Kernel-Panic sofort (→ `on_reboot`), `on_crash` greift nur bei Abstürzen, die Xen erkennt.

#### v2.2 Template-Stores nach Vertrauensgruppe (nixos-config)

- **Prinzip:** ein read-only erofs-Image pro Gruppe mit der Vereinigung aller Closures ihrer Mitglieder (`closureInfo` über alle toplevels), jedem Mitglied als `xvda` angehängt. Getestet 2026-10-05: zwei laufende Domains mit derselben Store-Disk (`access=ro`) gleichzeitig geht. Jede VM bootet ihre eigene toplevel aus dem gemeinsamen Image; Kernel/initrd kommen weiter pro VM aus dem dom0-Store. **Kein Overlay nötig.**
- **Registry:** neues Feld `storeGroup` (`sys` | `dev` | `desktop` | `prop` | `null` = standalone). Ein Modul baut daraus die Gruppen-Images und setzt `microvm.storeDisk` der Mitglieder. Zu prüfen: kein Eval-Zyklus (das Image hängt von den toplevels ab, die toplevels dürfen nicht vom Image abhängen; der Runner referenziert es, die toplevel nicht).
- **Update-Semantik:** neues Gruppen-Image → alle VMs der Gruppe neu starten (das alte Image bleibt offen, bis die VM stoppt). Das `vm`-Tool/TUI zeigt an, welche VMs ein veraltetes Image nutzen.
- **Build-Zeit:** erofs mit lz4 oder ohne Kompression; ein Image pro Gruppe statt pro VM.
- **Steam/HVM:** HVM ist unabhängig vom Store, auch ein HVM-Gast kann ein Gruppen-Image als Disk nutzen. Steam kommt in `prop` (Closure ist groß wegen 32-bit-Libs; falls `prop` dadurch zu schwer wird, eigene Gruppe).
- **Standalone (coding):** eigenes Image (Gruppe mit einem Mitglied) plus `persistent-store-overlay.nix`. Unter Xen fällt der virtiofs-`ro-store`-Share automatisch weg, unten liegt dann die Store-Disk. Testen: DB-Dump/-Load und GC über das Overlay.
- **Builder:** eigener großer RW-Store (ganzes `/nix` auf einem Volume), kein Template, siehe v2.4.
- **Umgesetzt 2026-10-06 (uncommitted):**
  - `vms/store-groups.nix`: baut pro Gruppe ein Image mit `microvm.lib.buildStoreDisk` über die `storeDiskContents` aller Mitglieder und liefert `moduleFor <vm>` (setzt `microvm.storeDisk`). Mitglied ist nur, wer `storeOnDisk` nutzt (Xen); VMs mit virtiofs-Store bleiben unberührt. Unterschiedliche `storeDiskType`/Flags innerhalb einer Gruppe → `throw`.
  - Eingehängt an beiden Stellen, an denen VMs evaluiert werden: Host (`microvm.vms` in `machines/common-configuration.nix`, Images aus den Host-Evaluierungen der VMs) und Flake (`nixosConfigurations.<vm>`/`packages.<vm>`). Kein Eval-Zyklus (getestet mit vault + nvim in einer Gruppe: beide bekommen dasselbe Image, auf beiden Wegen). Host und Flake evaluieren die VMs schon vorher leicht verschieden (anderer Runner-drvPath, auch ohne Gruppen), also bauen sie auch verschiedene Gruppen-Images; maßgeblich ist der Host.
  - Registry: `storeGroup` für alle VMs nach der Tabelle oben (auch auskommentierte; coding bleibt ohne = standalone). Auf dem hp sind heute nur nvim, vault, coding Xen-Gäste, also hat jede Gruppe höchstens ein Mitglied und die Images sind identisch mit vorher (kein Neubau). Die Gruppen greifen, sobald weitere VMs auf Xen umziehen.
  - Update-Semantik: `restartIfChanged` bleibt aus. `manage-vms status` zeigt Spalten `GROUP` und `IMAGE` (`ok`/`stale`: gebootetes Store-Image ≠ aktuelles, ermittelt über die Closure von `booted`/`current`), `manage-vms restart --stale` bzw. `--group <g>` startet gezielt neu. Altes Image bleibt durch die microvm-GC-Root `booted-<vm>` erhalten, solange die VM läuft.
  - Build-Zeit (gemessen am vault+nvim-Image auf dem hp): Default `-zlz4hc -Eztailpacking -Efragments` 108 s / 1,9 GB, `-zlz4 -Eztailpacking` 100 s / 2,1 GB, ohne Kompression 241 s / 3,6 GB (I/O-gebunden). → Default bleibt, kein Override. Der Gewinn kommt aus einem Image pro Gruppe statt pro VM.
  - Offen (Laufzeit, braucht Xen-Umzug weiterer VMs bzw. Test durch den User): zwei Gruppenmitglieder gleichzeitig booten; coding: devenv-Installation über Overlay + DB-Dump/-Load und GC (unverändert gegenüber vorher, `registerClosure = false`).

#### v2.3 RAM-Verwaltung

- **dom0 fest:** `dom0_mem=8192M,max:8192M`, `autoballoon="off"` in `xl.conf`. Sobald die Evaluierung in der Builder-VM läuft, kann dom0 kleiner werden (Ziel v3).
- **Gast-Agent** (in `common-config.nix`): schreibt periodisch `MemTotal/MemAvailable/Swap` nach xenstore (eigener Unterbaum der Domain).
- **dom0-Daemon:** liest die Werte, berechnet Ziel = genutzt × Faktor + Puffer, begrenzt auf `[mem, maxmem]` und auf den freien Host-RAM, setzt `xl mem-set`. Prioritäten pro VM aus der Registry. v2: einfaches Script/systemd-Service; später in Rust (passt zur TUI).
- **Umgesetzt 2026-10-06 (uncommitted):**
  - **dom0:** `autoballoon="off"` (Paket-`xl.conf` + angehängte Zeile, `machines/hp/xen.nix`). **Abweichung:** kein `max:8192M`, damit der README-Trick `xl mem-set 0 12g` für große Rebuilds weiter geht. dom0 bleibt trotzdem fest, weil weder xl noch der Daemon es anfassen.
  - **Gast-Agent** `vms/modules/xen-meminfo.nix` (importiert von `common-config.nix`), aktiv für Xen-Gäste mit `balloon` oder `hotplugMem`: schreibt alle 2 s `"MemTotal MemAvailable SwapTotal SwapFree"` (MiB) nach `~/data/meminfo` (laut Xen-Doku gastbeschreibbar, frei nutzbar), nur wenn sich ein Wert um ≥ 16 MiB bewegt hat. Eigener Mini-xenstore-Client (Binary + `libxenstore` + `libxentoolcore` aus dem Xen-Paket, ~130 KB) statt der 549-MB-Xen-Closure. Service als root (für `/dev/xen/xenbus`), ohne Netz, `ProtectSystem=strict`, nur dieses Device.
  - **dom0-Daemon** `modules/xen-memory.nix` (`services.xen-memory-balancer`, auf hp an): VM-Tabelle zur Build-Zeit aus `microvm.vms` (Untergrenze = Boot-RAM, Obergrenze = `maxmem`, gleiche Abbildung wie der Xen-Runner) + Registry `memPriority` (Default 0). Pro Runde (2 s): Ziel = genutzt (inkl. Swap) × 1,3 + 256 MiB, auf `[Boot, maxmem]` begrenzt, Hysterese 64 MiB. Schrumpfen sofort; Wachsen nur aus `free_memory` minus 2048 MiB Reserve (für VM-Starts), höhere Priorität zuerst, Rest anteilig an die nächste. Gastwerte werden strikt geprüft (vier Zahlen, sonst VM übersprungen). Alles per Option einstellbar.
  - **Opt-in:** verwaltet werden nur VMs mit Ballooning. nvim (2048–4096) und coding (4096–8192) jetzt mit `balloon`, vault wie gehabt (1024–2048).
  - **Getestet:** Build + shellcheck beider Skripte, Daemon-Logik offline mit Fake-`xl`/`xenstore-read` (Schrumpfen, Priorität bei knappem Budget, kein Budget, manipulierte Gastdaten), Dry-Run hp. **Offen (Laufzeit):** Agent schreibt im Gast wirklich (`xenstore-read /local/domain/<id>/data/meminfo` in dom0), Daemon-Log `journalctl -u xen-memory-balancer`, Lasttest aus v2.7.
  - **Laufzeittest 2026-10-06 (User):** nach Rebuild zeigte `manage-vms status` alle drei VMs als `stale`, `restart --stale` startete genau diese drei neu, danach `ok`. Agent schreibt (vault: `945 640 0 0` → genutzt 305 MiB → Ziel 652 → Untergrenze 1024 = Ist, daher keine Aktion, Daemon-Log korrekt leer). Wachsen unter Last noch offen (v2.7).
  - Hinweis: `microvm-balloon <size>` von Hand wird vom Daemon in der nächsten Runde überschrieben; für manuelle Tests `systemctl stop xen-memory-balancer`.

#### v2.4 Builder-VM und dom0 offline

Erkenntnis aus Branch `remote-builder`: dort evaluiert der Host und baut remote (`distributedBuilds`, `max-jobs = 0`), der Builder sieht den Host-Store per virtiofs-Overlay. Beides passt nicht zu Xen: dom0 bräuchte zum Evaluieren Netz (Flake-Inputs), und virtiofs gibt es nicht.

- **Neues Modell:** Der Builder **evaluiert und baut alles** (dom0-System, alle VMs, Gruppen-Images). dom0 holt nur fertige Closures über das Admin-Netz: `nix copy --from ssh-ng://builder <toplevel>` → `nix-env -p /nix/var/nix/profiles/system --set` → `switch-to-configuration`. Als Script in dom0 (z. B. `dom0-update`).
- **Vertrauen:** Der Builder signiert seine Outputs (`secret-key-files`), dom0 akzeptiert nur diesen Key (`trusted-public-keys`), keine anderen Substituter. Optional: Der Builder baut nur Git-Commits mit gültiger Signatur (`git verify-commit`), die Signaturen sind ja eingerichtet.
- **Repo-Fluss:** bearbeiten in einer Dev-VM → push auf den Git-Remote → der Builder pullt und baut. Passt zum Ziel "prebuild Workflows mit Remote-Git-Account".
- **Builder:** PVH, eigener RW-Store auf einem Volume, viel CPU/RAM (aus dem Branch: 16 vCPUs, 32 GB, auf dem hp kleiner), Uplink über sys-net, kein GUI. Übernehmen aus dem Branch: SSH-Setup, Substituter-Liste, Registry-Eintrag (IP `10.0.0.25`).
- **Übergang:** bis sys-net steht, bekommt der Builder Internet über NAT in dom0 (dom0 hat dann noch die WLAN-Karte). Mit v2.5 wird dom0 offline.
- **Recherche 2026-10-06 (noch nichts umgesetzt):**
  - **Branch `remote-builder`** (verwertbar): `vms/builder/default.nix` (cloud-hypervisor, virtiofs-ro-store + RW-Overlay, 32 GB/16 vCPU, Substituter-Liste), Registry-Eintrag (`builder`, `b`, `10.0.0.25`, MAC `…:19`, Host-Key), SSH-Block für `builder-vm`. Nicht übernehmen: `distributedBuilds`/`max-jobs = 0` (altes Modell). Auf dem hp gibt es noch keinen Builder-SSH-Key (`~/.ssh/builder-vm` fehlt).
  - **Store im Builder:** Xen bootet nur mit Store-Disk, also eigenes Image (standalone, keine Gruppe) + `writableStoreOverlay` auf einem großen Volume. Die Nix-DB muss zum Overlay passen. Variante A: bestehendes `persistent-store-overlay.nix` (DB-Dump/-Load, wie coding). Variante B: `/nix/var` persistent auf dem Volume + `registerClosure`; Risiko: nach einem Builder-Update stehen Pfade des alten Store-Images noch als gültig in der DB, obwohl sie fehlen → beim Boot `nix-store --verify` nötig. Empfehlung: A (erprobt).
  - **Platz/CPU/RAM hp:** 122 GB frei auf `/` (Store dom0 128 GB) → Overlay-Volume ~60 GB. 12 Threads, dom0 hat 4 → Builder 6–8 vCPUs. RAM: Eval-Spitze ~6,6 GB → Builder mit Ballooning 4096–16384 MB und hoher `memPriority` (v2.3).
  - **Vertrauen:** Pfade aus cache.nixos.org tragen nur deren Signatur. Damit dom0 **nur** den Builder-Key braucht, signiert der Builder nach dem Build die ganze Closure neu (`nix store sign --recursive -k <key> <toplevel>`; Lix 2.95 kann `nix store sign -r`, `nix key generate-secret`). dom0: `substituters = [ ]`, `trusted-public-keys = [ builder ]`, `require-sigs = true` (heute schon true).
  - **Ablauf (Pull durch dom0, nie Push vom Builder):** `dom0-update` in dom0 → `ssh builder build-hp` (fetch, optional `git verify-commit`, `nix build .#nixosConfigurations.hp…toplevel`, sign, gcroot, gibt Pfad aus) → `nix copy --from ssh-ng://builder-vm <pfad>` (root in dom0, eigener Key) → `nix-env -p /nix/var/nix/profiles/system --set` → `switch-to-configuration boot|switch`. `nixos-rebuild --target-host` vom Builder aus scheidet aus (VM hätte root in dom0).
  - **Gruppen-Images/Runner** stecken in der hp-Closure → kommen automatisch mit.
  - **Übergangs-NAT in dom0:** heute weder NAT noch Forwarding; VMs haben Gateway `10.0.0.253` (sys-net, auf dem hp nicht da). Builder bräuchte `gateway4 = 10.0.0.254` + `networking.nat` (nur Builder-IP, `externalInterface = wlo1`). Firewall-/NAT-Änderung in dom0 → **Zustimmung des Users nötig**.
  - **Entscheidungen (User, 2026-10-06):** (1) Repo-Quelle: **GitHub direkt** (`https://github.com/23b00t/nixos`, öffentlich → keine Credentials im Builder; Nachteil: jeder Build braucht einen Push; unfertige Stände später ggf. als `git bundle` über vmcopy); (2) `git verify-commit`: in v2 **nein**, in v3 erneut prüfen; (3) Übergangs-NAT in dom0 (nur Builder, über `wlo1`): **ja**; (4) Store: **`persistent-store-overlay.nix`**; (5) `dom0-update`: Default **`boot`**, `switch` als Option.
- **Umgesetzt 2026-10-06 (uncommitted):**
  - **Builder-VM** `vms/builder/default.nix` (Registry `builder`/`b`/`10.0.0.25`, `memPriority = 10`, kein vmcopy, standalone Store): Xen PVH, 8 vCPUs, Ballooning 4096–16384 MB, `persistent-store-overlay` (60 GB Overlay) + Volume `builder.img` (10 GB) unter `/var/lib/builder` (Repo-Checkout, Out-Links, Signing-Key). Lix kommt über `common-config`. Gateway `10.0.0.254` (Übergang).
  - **Signing-Key** wird beim ersten Boot im Builder erzeugt (`builder-signing-key.service`, `nix key generate-secret`, Name `builder-vm-1`); nur der Public Key verlässt die VM (`vms/builder/signing-key.pub` im Repo, dom0 vertraut ihm, sobald die Datei existiert; Muster wie `vms/vmcopy-keys`).
  - **`builder-build <machine> [branch]`** (im Builder): clone/fetch von GitHub, `--detach FETCH_HEAD`, `nix build` mit Out-Link `/var/lib/builder/systems/<machine>`, `nix store sign --recursive`, gibt den Toplevel-Pfad aus. Out-Links per tmpfiles als GC-Roots (`/nix/var` ist flüchtig), damit der DB-Dump des Overlays die letzten Builds behält.
  - **`dom0-update [--switch] [--machine] [--branch]`** (dom0, `modules/dom0-update.nix`): `ssh 10.0.0.25 builder-build …` → Plausibilitätsprüfung des Pfads → `nix copy --from ssh-ng://10.0.0.25` **als normaler User** (der nix-daemon nimmt die Pfade nur mit gültiger Builder-Signatur an) → `sudo nix-env -p …/system --set` → `switch-to-configuration boot` (Default) bzw. `switch`. Ohne `signing-key.pub` bricht es mit Hinweis ab. Per IP, weil die SSH-Blöcke `Host <vm>-vm <ip>` keinen `HostName` haben.
  - **Übergangs-NAT** (`machines/hp/xen.nix`): `networking.nat` nur für `10.0.0.25/32` über `wlo1`, plus eigene iptables-Kette `builder-only-fwd`, die alles andere von `vm-internal` nach `wlo1` verwirft (NAT schaltet Forwarding global ein).
  - dom0 behält bis v2.5 seine Substituter (additiv nur Builder-Key). Mit v2.5: `substituters = [ ]`, nur Builder-Key.
  - **Getestet:** Build + shellcheck beider Skripte; `dom0-update --help` und Abbruch ohne Key; `builder-build vault hp` lokal mit Scratch-Verzeichnis (Clone von GitHub, Branch, Build, Out-Link; Signieren ausgelassen); Key-Erzeugung; iptables-Regeln im generierten Firewall-Skript (`bash -n`); Dry-Run hp. **Offen (Laufzeit):** Builder booten, Internet über NAT, erster `dom0-update`.

#### v2.5 sys-net (mit Firewall) und Netz-Topologie

- **sys-net:** HVM, WLAN-Karte `01:00.0` (RTL8821CE) per Passthrough, NetworkManager im Gast, nftables-Firewall (Regeln aus dem heutigen `vms/sys-net/default.nix` übernehmen), `xl devd` als Backend für die Uplink-vifs. sys-firewall wird später abgespalten.
- **Zwei Netze pro VM:**
  - **Admin-Netz** `vm-internal` in dom0 (bestehend, `10.0.0.0/24`, dom0 `10.0.0.254`, vif `vm<N>`): nur SSH/wprs/DBus-/Agent-Forwards von dom0. **Bridge-Port-Isolation** auf allen vifs (`bridge link set dev vm<N> isolated on`), damit VMs sich darüber nicht gegenseitig erreichen. In der VM: nur SSH von `10.0.0.254` auf diesem Interface, keine Default-Route.
  - **Uplink-Netz** mit Backend sys-net (eigenes Subnetz, z. B. `10.1.0.0/24`, sys-net `.254`): Default-Route der VM. Nur VMs mit `nat = true` in der Registry bekommen einen Uplink (vault z. B. nicht).
  - dom0 hängt **nicht** am Uplink-Netz.
- **Inter-VM-Copy (`cp-vm`/vmcopy):** läuft heute VM↔VM per SSH. Mit isoliertem Admin-Netz geht das über das Uplink-Netz mit expliziten Firewall-Regeln pro erlaubtem Paar in sys-net (Qubes-Prinzip: die Firewall entscheidet). Langfristig über vchan (siehe "Nach v2").
- **Vorbereitung 2026-10-06 (Recherche, nichts umgesetzt):**
  - **Ist-Stand:** `vms/sys-net/default.nix` ist cloud-hypervisor mit virtiofs-Store, tap `vm-router` (`10.0.0.253`), libvirt-Zonen (`vm-libv-def`, `vm-whx-ext`, dnsmasq), nftables mit Host-Egress-Regeln für `10.0.0.254`, NAT, NM, CUPS/Avahi. Registry auf dem hp: `pciDevicePaths.nic`/`pciDeviceIds.nic`/`blockedHostDrivers` sind leere TODOs. WLAN `0000:01:00.0` (`10ec:c821`, Treiber `rtw88_8821ce`) hängt heute an dom0 (`wlo1`, auch Übergangs-NAT aus v2.4).
  - **Umbau sys-net (VM):** `hypervisor = "xen"`, `xen.type = "hvm"`, `xen.driverDomain = true`, `boot.kernelParams = [ "pci=nomsi" ]` (MSI-X-Problem aus v2.1), `devices` aus der Registry, `mem` ohne Ballooning (Passthrough), `storeGroup = "sys"` steht schon. libvirt-Zonen + dnsmasq auf dem hp weglassen (libvirt ist dort aus). Neue Bridge `vm-uplink` in sys-net (`10.1.0.254/24`), NAT/Forward von `vm-uplink` ins WLAN; NM verwaltet nur das WLAN.
  - **Uplink je VM:** zweites Interface `uplink` (`type = "bridge"`, `bridge = "vm-uplink"`, `xen.interfaceBackends.uplink = "sys-net-vm"`, vif ohne `vifname`, siehe v2.1) nur für `nat = true`. `net-config.nix` braucht dafür eine Erweiterung: Admin-Interface ohne Default-Route, Uplink-Interface `10.1.0.<index>/24` mit Gateway `10.1.0.254` + DNS. Builder wechselt vom Übergangs-NAT auf den Uplink.
  - **Admin-Netz isolieren:** Bridge-Port-Isolation per networkd (`[Bridge] Isolated = true` in den `.network`-Dateien der `vm*`-Ports in dom0). Isolierte Ports reden nur mit nicht-isolierten → dom0 (Bridge-Interface selbst) ↔ VM geht weiter (SSH, wprs, vm-run, DBus/Agent-Forwards), VM ↔ VM nicht mehr.
  - **Folgen der Isolation:** vmcopy (VM↔VM-SSH über Admin-Netz) und der Druck-Tunnel office → sys-net (`10.0.0.253`) brechen; beide müssten über das Uplink-Netz + Regeln in sys-net laufen.
  - **dom0 offline:** WLAN-Gerät per `xl pci-assignable-add` beim sys-net-Start (vorhandene Fork-Logik, mit dem USB-Controller getestet) oder schon beim Boot per `xen-pciback.hide=(0000:01:00.0)` (Qubes-Weg, dom0 sieht die Karte nie; braucht pciback vor `rtw88`). Danach: Übergangs-NAT + `builder-only-fwd` aus v2.4 entfernen, dom0 `substituters = [ ]` + nur Builder-Key, NM in dom0 ohne WLAN. **Notausgang** (falls sys-net nicht hochkommt): `xl pci-assignable-remove -r 0000:01:00.0` gibt die Karte an dom0 zurück (mit dem USB-Controller getestet), als kleines Script `sys-net-rescue` mitliefern.
  - **Entscheidungen vor der Umsetzung (Firewall/SSH = nur mit Zustimmung):** (a) sys-net-Firewall: bestehende Regeln auf `vm-uplink` umschreiben (Host-Regeln für `10.0.0.254` entfallen, dom0 hängt nicht am Uplink), ok?; (b) Adressplan Uplink `10.1.0.0/24`, VM = `10.1.0.<index>`, sys-net `.254`, ok?; (c) vmcopy + Druck-Tunnel in v2.5: Paar-Regeln in sys-net über das Uplink-Netz, oder bis vchan vorübergehend aus?; (d) WLAN-Übergabe: `pci-assignable-add` beim VM-Start (erprobt) oder `xen-pciback.hide` beim Boot?; (e) In jeder VM eine Regel „auf dem Admin-Interface nur SSH von `10.0.0.254`“ (Gast-Firewall) jetzt schon oder erst mit vchan?; (f) `pci=nomsi` für WLAN akzeptieren (Durchsatz testen)?

#### v2.6 sys-usb und Webcam

- **sys-usb:** HVM, beide xHCI-Controller des hp per Passthrough: `03:00.3` und `03:00.4` (`1022:1639`; daran hängen Kamera `0408:5365`, Bluetooth `0bda:b00e`, Fingerprint `04f3:0c00`). Tastatur (i8042) und Touchpad (I2C) hängen nicht an USB, das Durchreichen ist auf dem hp also unkritisch.
- **XMG: USB-Tastatur und -Maus per Input-Proxy (Entscheidung 2026-10-05).** Passthrough geht nur pro Controller, und am XMG ist kein Controller nur für Eingabegeräte frei. Deshalb gehen alle USB-Controller an sys-usb, und die Eingaben kommen über einen Input-Proxy zurück zu dom0 (wie `qubes-input-proxy`):
  - sys-usb liest nur die evdev-Geräte der in der Registry freigegebenen Vendor:Product-IDs (Basis: die heutigen USBGuard-Regeln des XMG) und gibt deren Events aus.
  - dom0 startet die Verbindung selbst (SSH über das Admin-Netz, gleiche Richtung wie alle Admin-Pfade), prüft die Events (nur Tasten-, Relativ- und Absolut-Events) und speist sie per `uinput` in dom0 ein. Später über vchan.
  - **LUKS/initrd:** Die Controller werden erst zur Laufzeit an `pciback` übergeben (`xl pci-assignable-add` beim Start von sys-usb), **nicht** per `xen-pciback.hide` auf der Kernel-Zeile. So hat dom0 im initrd noch die Tastatur für die Passphrase.
  - **Ausfall:** Startet sys-usb nicht, hat dom0 keine Tastatur/Maus mehr. Fallback: Kommt sys-usb nicht innerhalb eines Timeouts hoch, gibt dom0 die Controller zurück an den eigenen Treiber (`xl pci-assignable-remove -r`).
  - **Risiko:** Ein kompromittiertes sys-usb kann Eingaben in dom0 injizieren (wie bei Qubes). Gegenmittel: nur freigegebene IDs, Event-Filter in dom0, neue Eingabegeräte nur nach Bestätigung in dom0.
  - **Testbar auf dem hp** mit externer USB-Maus/-Tastatur, obwohl die internen Geräte dort nicht an USB hängen.
- **Webcam → chat per USB/IP:** `usbipd` in sys-usb, `vhci-hcd` in chat. Transport über einen eigenen Punkt-zu-Punkt-Link: chat bekommt ein drittes vif mit `backend=sys-usb` (z. B. `10.2.0.0/30`), damit der Verkehr weder durch dom0 noch durch sys-net läuft. USB/IP hat keine Authentifizierung oder Verschlüsselung, deshalb nur auf diesem Link und mit Firewall in sys-usb.
- **Zuordnung** aus der Registry (`hardware.usb`-Inventar und Owner): systemd-Units in sys-usb (bind) und in der Ziel-VM (attach) werden daraus generiert.
- **Bluetooth** lebt in sys-usb. Offen: Audio über BT-Headsets (pipewire läuft in dom0) → später.

#### v2.7 Tests / Definition of Done

- PVH-Gast balloont unter Last bis `maxmem` und gibt wieder ab; dom0 bleibt bei 8192 MB.
- Zwei VMs derselben Gruppe booten vom selben Image; ein Gruppen-Update startet genau die Gruppe neu.
- coding: devenv-Installation übersteht einen Neustart (Overlay + DB).
- dom0-Update nur über den Builder; dom0 hat keine Default-Route und keine NIC.
- sys-net: WLAN geht, VMs mit `nat = true` haben Internet, vault nicht, VMs erreichen sich nicht über das Admin-Netz, wprs/`vm-run` laufen weiter.
- sys-usb: Webcam in chat (Videocall-Test), Bluetooth in sys-usb gekoppelt.
- Alte Testplan-Punkte (Lifecycle, Shutdown) bleiben grün, jetzt auch für HVM-Gäste.

### Nach v2 (festgehalten, nicht Teil von v2)

- **GUI und Admin über vchan:** ein Relay (Rust, libxenvchan), das Unix-Sockets zwischen dom0 und VM durchreicht (wprs, DBus-Forward, GitHub-Agent). Danach fällt das Admin-vif weg und dom0 hat gar keine Netzverbindung zu VMs mehr.
- **qrexec-artige RPCs über vchan** für Copy und Clipboard (Roadmap-Punkt wprs-Clipboard) statt SSH/Netz.
- **Stubdomains** für die Device-Models der HVM-Gäste (sys-net, sys-usb, Steam), damit qemu nicht mehr in dom0 läuft.
- sys-firewall abspalten (später evtl. MirageOS), USB über vchan statt USB/IP.

### Offen

- Adressplan für Uplink- und USB-Links festlegen.
- Woher der Builder das Repo zieht (GitHub direkt vs. Spiegel) und ob Signaturprüfung Pflicht ist.
- BT-Audio mit sys-usb.
- MSI-X bei PCI-Passthrough mit PVH-dom0 (ENODATA in qemu `msi_msix_setup`): Ursache klären, damit Driver-Domains ohne `pci=nomsi` laufen. Ansätze: `xl dmesg` mit `iommu=debug`, qemu-xen-Version, Xen-Patches von Jiqian Chen (AMD) zu PVH-dom0-Passthrough.

## v3

- Ausführliche Review des bisherigen Codes
- Alles VMs lauffähig auf Test
- Build VM und dom0 RAM reduzieren
- Builder: `git verify-commit` vor jedem Build (Signing-Pubkey als `allowedSignersFile` im Builder), aus v2.4 zurückgestellt
- Lösung für Tails als HVM testen.
- Lösung für Steam VM als HVM (ist das auch ohne dGPU testbar?)
- Whonix Stack und Kali als PVH integrieren

## v4

- config refactorn
- Auslagern der spezifischen Config in ein neues Repo das das Betriebssystem Repo wird und später Dinge wie die Verwaltungs TUI etc. enthält. Den dom0 code so verallgemeinern, dass er auf "jeder" (also erstmal dem xmg) Hardware läuft. Die VM configs als Templates/ Beispiele im Repo. Design entwickeln.

- Auf XMG testen
- dGPU passthrough implementieren

## v5

- Installer entwickeln
- Admin Tooling, Scripts, TUI etc. entwickeln
- Alle Scripts (manage-vms, vm-run, vm, dom0-update, …) bekommen Shell-Autocompletion (zsh)
- Feintuning (Niri etc.)
- Neue VMs und Services: z.B. SSH und GPG in eigener VM, Socket teilen

## Sonstiges für die ferne Zukunft

- sys-firewall evtl auf MirrageOS
- Prüfen, ob Dom0 von nixos weg kann, auf irgendeinen rust basierten micro kernel
- Kann der Grafikstack von dom0 in eine appvm?
