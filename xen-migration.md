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
  - **Umgesetzt 2026-10-05 (Fork, uncommitted):** `microvm.xen.type` und `microvm.xen.qemuPackage` (Default `qemu_xen`). HVM: `bzImage` statt `vmlinux`, `device_model_override` auf qemu-xen, `vga = "none"`, vifs mit `type=vif` (kein emuliertes NIC).
  - **HVM-Disks ab `xvde`:** qemu-xen emuliert `xvda`–`xvdd` zusätzlich als IDE und kann das nicht read-only (`qemu-xen doesn't support read-only IDE disk drivers`). Neue Funktion `firstDiskIndex` in `lib/default.nix` verschiebt Store-Disk und Volumes bei HVM um 4 Buchstaben; Gast (`withDriveLetters`) und Runner nutzen dieselbe Funktion. Die Store-Disk mountet der Gast ohnehin per erofs-Label.
  - **Getestet auf dem hp:** HVM-Testdomain (vault-System, ohne Netz) bootet bis zum Login, Console-Log über `hvc0` geht, Ballooning per PoD geht (2047 ↔ 767), sauberer Shutdown beendet auch qemu. qemu braucht ~93 MB RSS in dom0 pro HVM-Gast (für das dom0-RAM-Budget).
  - **PV-Gäste sind auf AMD mit Gast-Kernel 6.18 kaputt:** Panic in `print_s5_reset_status_mmio` (liest FCH-MMIO bei `0xfed80…`, das ein PV-Gast nicht hat). Kernel-Bug, nicht unsere Config. PV bleibt als Option drin, ist aber auf dem hp nicht nutzbar (auf dem XMG mit Intel-CPU evtl. schon).
- **PCI-Passthrough:** bestehendes `microvm.devices` (`bus = "pci"`) → `pci = [ … ]` im xl.cfg; `throw`, wenn nicht `type = "hvm"`.
  - Host: `microvm-pci-devices@<vm>` bindet heute an `vfio-pci`; unter Xen stattdessen `xl pci-assignable-add` (bindet an `pciback`). Gerätelisten weiter aus `registry.nix` (`hardware.pci`).
  - **Umgesetzt 2026-10-05 (Fork, uncommitted):** Runner schreibt `pci = [ … ]`; `throw` bei PVH/PV (nur HVM), bei `bus = "usb"` (USB geht über sys-usb) und bei `memory < maxmem` (Passthrough verträgt kein Populate-on-Demand, also kein Ballooning beim Boot). `pci-devices.nix` erzeugt für Xen ein `pci-setup` mit `xl pci-assignable-add` (idempotent) statt vfio-pci.
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
  - **Umgesetzt 2026-10-05 (Fork, uncommitted):** Abbildung wie oben im Xen-Runner, plus `setBalloonScript` → `microvm-balloon <size-mb>` (`xl mem-set <vm> (maxmem - size)`, mit `timeout`). Erster Nutzer: vault (`mem = 2048`, `balloon = true`, `initialBalloonMem = 1024`), läuft auf dem hp. `deflateOnOOM` ohne Warnung (Default `true` hätte bei jeder Balloon-VM gewarnt).
- **Netz-Backend pro Interface:** xen-spezifische Option (z. B. `microvm.xen.interfaceBackends.<id> = "sys-net-vm"`) → `backend=` im vif. Kein Eingriff ins upstream-Interface-Schema.
- **Geteiltes Store-Image:** `microvm.storeDisk` muss auf ein fremdes (Gruppen-)Image zeigen dürfen; Disk mit `access=ro` (Xens Block-Script erlaubt mehrere Leser).
- **Driver-Domain-Unterstützung im Gast:** Modul, das in sys-net/sys-usb `xl devd` startet (dort laufen dann die vif-Hotplug-Scripts) und die Xen-Tools bereitstellt.
- Weitere Optionen, die sich lohnen: `vcpus`/`maxvcpus`, CPU-Pinning bzw. cpupools, credit2 `weight`/`cap` (UX, z. B. Steam), `on_crash`-Policy. `microvm.xen.extraConfig` bleibt als Notausgang.

#### v2.2 Template-Stores nach Vertrauensgruppe (nixos-config)

- **Prinzip:** ein read-only erofs-Image pro Gruppe mit der Vereinigung aller Closures ihrer Mitglieder (`closureInfo` über alle toplevels), jedem Mitglied als `xvda` angehängt. Getestet 2026-10-05: zwei laufende Domains mit derselben Store-Disk (`access=ro`) gleichzeitig geht. Jede VM bootet ihre eigene toplevel aus dem gemeinsamen Image; Kernel/initrd kommen weiter pro VM aus dem dom0-Store. **Kein Overlay nötig.**
- **Registry:** neues Feld `storeGroup` (`sys` | `dev` | `desktop` | `prop` | `null` = standalone). Ein Modul baut daraus die Gruppen-Images und setzt `microvm.storeDisk` der Mitglieder. Zu prüfen: kein Eval-Zyklus (das Image hängt von den toplevels ab, die toplevels dürfen nicht vom Image abhängen; der Runner referenziert es, die toplevel nicht).
- **Update-Semantik:** neues Gruppen-Image → alle VMs der Gruppe neu starten (das alte Image bleibt offen, bis die VM stoppt). Das `vm`-Tool/TUI zeigt an, welche VMs ein veraltetes Image nutzen.
- **Build-Zeit:** erofs mit lz4 oder ohne Kompression; ein Image pro Gruppe statt pro VM.
- **Steam/HVM:** HVM ist unabhängig vom Store, auch ein HVM-Gast kann ein Gruppen-Image als Disk nutzen. Steam kommt in `prop` (Closure ist groß wegen 32-bit-Libs; falls `prop` dadurch zu schwer wird, eigene Gruppe).
- **Standalone (coding):** eigenes Image (Gruppe mit einem Mitglied) plus `persistent-store-overlay.nix`. Unter Xen fällt der virtiofs-`ro-store`-Share automatisch weg, unten liegt dann die Store-Disk. Testen: DB-Dump/-Load und GC über das Overlay.
- **Builder:** eigener großer RW-Store (ganzes `/nix` auf einem Volume), kein Template, siehe v2.4.

#### v2.3 RAM-Verwaltung

- **dom0 fest:** `dom0_mem=8192M,max:8192M`, `autoballoon="off"` in `xl.conf`. Sobald die Evaluierung in der Builder-VM läuft, kann dom0 kleiner werden (Ziel v3).
- **Gast-Agent** (in `common-config.nix`): schreibt periodisch `MemTotal/MemAvailable/Swap` nach xenstore (eigener Unterbaum der Domain).
- **dom0-Daemon:** liest die Werte, berechnet Ziel = genutzt × Faktor + Puffer, begrenzt auf `[mem, maxmem]` und auf den freien Host-RAM, setzt `xl mem-set`. Prioritäten pro VM aus der Registry. v2: einfaches Script/systemd-Service; später in Rust (passt zur TUI).

#### v2.4 Builder-VM und dom0 offline

Erkenntnis aus Branch `remote-builder`: dort evaluiert der Host und baut remote (`distributedBuilds`, `max-jobs = 0`), der Builder sieht den Host-Store per virtiofs-Overlay. Beides passt nicht zu Xen: dom0 bräuchte zum Evaluieren Netz (Flake-Inputs), und virtiofs gibt es nicht.

- **Neues Modell:** Der Builder **evaluiert und baut alles** (dom0-System, alle VMs, Gruppen-Images). dom0 holt nur fertige Closures über das Admin-Netz: `nix copy --from ssh-ng://builder <toplevel>` → `nix-env -p /nix/var/nix/profiles/system --set` → `switch-to-configuration`. Als Script in dom0 (z. B. `dom0-update`).
- **Vertrauen:** Der Builder signiert seine Outputs (`secret-key-files`), dom0 akzeptiert nur diesen Key (`trusted-public-keys`), keine anderen Substituter. Optional: Der Builder baut nur Git-Commits mit gültiger Signatur (`git verify-commit`), die Signaturen sind ja eingerichtet.
- **Repo-Fluss:** bearbeiten in einer Dev-VM → push auf den Git-Remote → der Builder pullt und baut. Passt zum Ziel "prebuild Workflows mit Remote-Git-Account".
- **Builder:** PVH, eigener RW-Store auf einem Volume, viel CPU/RAM (aus dem Branch: 16 vCPUs, 32 GB, auf dem hp kleiner), Uplink über sys-net, kein GUI. Übernehmen aus dem Branch: SSH-Setup, Substituter-Liste, Registry-Eintrag (IP `10.0.0.25`).
- **Übergang:** bis sys-net steht, bekommt der Builder Internet über NAT in dom0 (dom0 hat dann noch die WLAN-Karte). Mit v2.5 wird dom0 offline.

#### v2.5 sys-net (mit Firewall) und Netz-Topologie

- **sys-net:** HVM, WLAN-Karte `01:00.0` (RTL8821CE) per Passthrough, NetworkManager im Gast, nftables-Firewall (Regeln aus dem heutigen `vms/sys-net/default.nix` übernehmen), `xl devd` als Backend für die Uplink-vifs. sys-firewall wird später abgespalten.
- **Zwei Netze pro VM:**
  - **Admin-Netz** `vm-internal` in dom0 (bestehend, `10.0.0.0/24`, dom0 `10.0.0.254`, vif `vm<N>`): nur SSH/wprs/DBus-/Agent-Forwards von dom0. **Bridge-Port-Isolation** auf allen vifs (`bridge link set dev vm<N> isolated on`), damit VMs sich darüber nicht gegenseitig erreichen. In der VM: nur SSH von `10.0.0.254` auf diesem Interface, keine Default-Route.
  - **Uplink-Netz** mit Backend sys-net (eigenes Subnetz, z. B. `10.1.0.0/24`, sys-net `.254`): Default-Route der VM. Nur VMs mit `nat = true` in der Registry bekommen einen Uplink (vault z. B. nicht).
  - dom0 hängt **nicht** am Uplink-Netz.
- **Inter-VM-Copy (`cp-vm`/vmcopy):** läuft heute VM↔VM per SSH. Mit isoliertem Admin-Netz geht das über das Uplink-Netz mit expliziten Firewall-Regeln pro erlaubtem Paar in sys-net (Qubes-Prinzip: die Firewall entscheidet). Langfristig über vchan (siehe "Nach v2").

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
- Feintuning (Niri etc.)
- Neue VMs und Services: z.B. SSH und GPG in eigener VM, Socket teilen

## Sonstiges für die ferne Zukunft

- sys-firewall evtl auf MirrageOS
- Prüfen, ob Dom0 von nixos weg kann, auf irgendeinen rust basierten micro kernel
- Kann der Grafikstack von dom0 in eine appvm?
