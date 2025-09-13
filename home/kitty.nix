# kitty.nix - kitty config as string
let
  kittyConf = ''
	include current-theme.conf

	font_family      DroidSansM Nerd Font 
	bold_font        auto
	italic_font      auto
	bold_italic_font auto

	font_size 12.0

	cursor_shape block
	cursor_shape_unfocused hollow

	scrollback_lines 2000
	scrollback_indicator_opacity 0.6
	mouse_hide_wait 3.0

	url_style double
	open_url_with default
	detect_urls yes
	show_hyperlink_targets yes 

	copy_on_select no
	paste_actions quote-urls-at-prompt,confirm

	default_pointer_shape beam
	pointer_shape_when_dragging beam

	repaint_delay 10
	input_delay 3

	sync_to_monitor yes
	enable_audio_bell no 
	visual_bell_duration 0.5
	visual_bell_color none
	window_alert_on_bell yes
	bell_on_tab "🔔 "
	remember_window_size  yes
	draw_minimal_borders yes
	hide_window_decorations yes 

	tab_bar_margin_width      1 
  # tab_bar_style             separator
	tab_bar_style             hidden
	tab_bar_align center
	tab_bar_edge bottom
	tab_bar_min_tabs          1
	tab_title_max_length 23
	tab_separator             ""
	tab_title_template        "{fmt.fg._323449}{fmt.bg.default}{fmt.fg._04d1f9}{fmt.bg.default}{index}{fmt.fg._04d1f9}{fmt.bg._323449} {title[:15] + (title[15:] and '…')} {fmt.fg._323449}{fmt.bg.default} "
	active_tab_title_template "{fmt.fg._37f499}{fmt.bg.default}{fmt.fg._212337}{fmt.bg._37f499}{fmt.fg._212337}{fmt.bg._37f499} {title[:40] + (title[40:] and '…')} {fmt.fg._37f499}{fmt.bg.default} "

	background_opacity 0.8
	# background_blur 5 
	# background_image ~/Pictures/galaxy_kaleidoscope.png
	# background_image_layout cscaled
	# background_image_linear no
	# dynamic_background_opacity no
	# background_tint 0.5

	shell zsh
	editor nvim

	close_on_child_death no

	allow_remote_control yes 
	listen_on unix:@mykitty

	startup_session ./startup

	clipboard_control write-clipboard write-primary read-clipboard-ask read-primary-ask

	allow_hyperlinks yes

	shell_integration enabled

	allow_cloning ask

	map ctrl+shift+c copy_to_clipboard
	map ctrl+v paste_from_clipboard
	map ctrl+alt+1 goto_tab 1
	map ctrl+alt+2 goto_tab 2
	map ctrl+alt+3 goto_tab 3
	map ctrl+alt+4 goto_tab 4
	map ctrl+alt+5 goto_tab 5
	map ctrl+alt+6 goto_tab 6
	map ctrl+alt+7 goto_tab 7
	map ctrl+alt+8 goto_tab 8
	map ctrl+alt+9 goto_tab 9

	map ctrl+alt+enter launch --cwd=current
	map ctrl+alt+w select_tab
  '';
in
  kittyConf

