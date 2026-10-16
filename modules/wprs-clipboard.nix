# Clipboard isolation for wprs (Qubes model, 2026-10-16). `patch`: wprsd
# exchanges no selection with dom0 while WPRS_NO_SELECTION_SYNC is set, and
# offers wlr-data-control, so wl-copy/wl-paste reach the guest clipboard
# without a window. `helper`: what dom0's vm-clip (home/vm-management/vm-gui.nix)
# calls in the guest over SSH. Used by the NixOS VMs (vms/modules/wprs.nix)
# and dom0's wprs, which the image domains get (modules/xen-image-domains.nix)
{ pkgs }:
{
  patch = pkgs.writeText "wprs-selection-isolation.patch" ''
    diff --git a/src/server/client_handlers.rs b/src/server/client_handlers.rs
    index 8407116..e1c6308 100644
    --- a/src/server/client_handlers.rs
    +++ b/src/server/client_handlers.rs
    @@ -918,6 +918,8 @@ impl WprsServerState {
                         },
                     );
                 },
    +            DataEvent::DestinationEvent(DataDestinationEvent::SelectionSet(_, _))
    +                if std::env::var_os("WPRS_NO_SELECTION_SYNC").is_some() => {},
                 DataEvent::DestinationEvent(DataDestinationEvent::SelectionSet(source, metadata)) => {
                     match source {
                         DataSource::Selection => data_device::set_data_device_selection(
    diff --git a/src/server/mod.rs b/src/server/mod.rs
    index 61c8a22..4b73c79 100644
    --- a/src/server/mod.rs
    +++ b/src/server/mod.rs
    @@ -36,6 +36,7 @@ use smithay::wayland::compositor::SurfaceData;
     use smithay::wayland::compositor::TraversalAction;
     use smithay::wayland::selection::data_device::DataDeviceState;
     use smithay::wayland::selection::primary_selection::PrimarySelectionState;
    +use smithay::wayland::selection::wlr_data_control::DataControlState;
     use smithay::wayland::shell::kde::decoration::KdeDecorationState;
     use smithay::wayland::shell::xdg::XdgShellState;
     use smithay::wayland::shell::xdg::decoration::XdgDecorationState;
    @@ -99,6 +100,7 @@ pub struct WprsServerState {
         pub seat_state: SeatState<Self>,
         pub data_device_state: DataDeviceState,
         pub primary_selection_state: PrimarySelectionState,
    +    pub data_control_state: DataControlState,
         pub viewporter_state: ViewporterState,

         pub seat: Seat<Self>,
    @@ -142,6 +144,11 @@ impl WprsServerState {
                 KdeDecorationMode::Client
             };

    +        let primary_selection_state = PrimarySelectionState::new::<Self>(&dh);
    +        // Clipboard access for local tools (wl-copy/wl-paste) without a window
    +        let data_control_state =
    +            DataControlState::new::<Self, _>(&dh, Some(&primary_selection_state), |_| true);
    +
             Self {
                 dh: dh.clone(),
                 lh,
    @@ -155,7 +162,8 @@ impl WprsServerState {
                 shm_state: ShmState::new::<Self>(&dh, Vec::new()),
                 seat_state,
                 data_device_state: DataDeviceState::new::<Self>(&dh),
    -            primary_selection_state: PrimarySelectionState::new::<Self>(&dh),
    +            primary_selection_state,
    +            data_control_state,
                 viewporter_state: ViewporterState::new::<Self>(&dh),
                 seat,
                 serializer,
    diff --git a/src/server/smithay_handlers.rs b/src/server/smithay_handlers.rs
    index f4a1a91..87633cd 100644
    --- a/src/server/smithay_handlers.rs
    +++ b/src/server/smithay_handlers.rs
    @@ -82,6 +82,8 @@ use smithay::wayland::selection::SelectionSource;
     use smithay::wayland::selection::SelectionTarget;
     use smithay::wayland::selection::primary_selection::PrimarySelectionHandler;
     use smithay::wayland::selection::primary_selection::PrimarySelectionState;
    +use smithay::wayland::selection::wlr_data_control::DataControlHandler;
    +use smithay::wayland::selection::wlr_data_control::DataControlState;
     use smithay::wayland::shell::kde::decoration::KdeDecorationHandler;
     use smithay::wayland::shell::kde::decoration::KdeDecorationState;
     use smithay::wayland::shell::xdg::Configure;
    @@ -421,6 +423,11 @@ impl SelectionHandler for WprsServerState {
             source: Option<SelectionSource>,
             _seat: Seat<Self>,
         ) {
    +        // Clipboard isolation: the selection stays in this VM, transfers to
    +        // and from the host go through explicit copy/paste
    +        if std::env::var_os("WPRS_NO_SELECTION_SYNC").is_some() {
    +            return;
    +        }
             if let Some(source) = source {
                 self.serializer
                     .writer()
    @@ -475,6 +482,12 @@ impl DataDeviceHandler for WprsServerState {
         }
     }

    +impl DataControlHandler for WprsServerState {
    +    fn data_control_state(&self) -> &DataControlState {
    +        &self.data_control_state
    +    }
    +}
    +
     impl PrimarySelectionHandler for WprsServerState {
         fn primary_selection_state(&self) -> &PrimarySelectionState {
             &self.primary_selection_state
    @@ -1249,4 +1262,5 @@ smithay::delegate_seat!(WprsServerState);
     smithay::delegate_data_device!(WprsServerState);
     smithay::delegate_output!(WprsServerState);
     smithay::delegate_primary_selection!(WprsServerState);
    +smithay::delegate_data_control!(WprsServerState);
     smithay::delegate_viewporter!(WprsServerState);
  '';

  # Called by dom0's vm-clip over SSH: `get` prints the text clipboard,
  # `set` takes it on stdin. wl-copy keeps serving it, detached from SSH
  helper = pkgs.writeShellScriptBin "vm-clip-helper" ''
    set -eu
    export WAYLAND_DISPLAY=wprs-0
    export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    case "''${1:-}" in
      get) exec ${pkgs.wl-clipboard}/bin/wl-paste --no-newline --type text ;;
      set)
        tmp="$(mktemp)"
        trap 'rm -f "$tmp"' EXIT
        cat >"$tmp"
        ${pkgs.util-linux}/bin/setsid ${pkgs.wl-clipboard}/bin/wl-copy --type text/plain \
          <"$tmp" >/dev/null 2>&1
        ;;
      *)
        echo "usage: vm-clip-helper get|set" >&2
        exit 2
        ;;
    esac
  '';
}
