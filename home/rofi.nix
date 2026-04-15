{
  config,
  lib,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    rofi # application launcher
  ];

  home.file = {
    # Tokio-Night-Rofi-Theme
    ".config/rofi/theme.rasi" = {
      text = ''
        configuration {
          modi: "drun,run,window";
          font: "FiraCode Nerd Font 11";
          show-icons: true;
          icon-theme: "Tela-dark";
          display-drun: "Apps";
          display-run: "Run";
          display-window: "Windows";
        }

        * {
          bg: #1a1b26;
          bg-alt: #16161e;
          fg: #c0caf5;
          accent: #7aa2f7;
          accent2: #bb9af7;
          urgent: #f7768e;

          background-color: @bg;
          text-color: @fg;
        }

        window {
          transparency: "real";
          location: center;
          width: 40%;
          border: 2px;
          border-color: @accent;
          border-radius: 10;
          padding: 10;
        }

        mainbox {
          background-color: @bg;
          spacing: 8;
          padding: 10;
        }

        inputbar {
          background-color: @bg-alt;
          padding: 6 10;
          border-radius: 8;
          children: [prompt, entry];
        }

        prompt {
          text-color: @accent2;
        }

        entry {
          placeholder: "Search…";
        }

        listview {
          background-color: @bg;
          spacing: 4;
          scrollbar: false;
        }

        element {
          padding: 4 8;
          border-radius: 6;
        }

        element normal {
          background-color: transparent;
          text-color: @fg;
        }

        element selected {
          background-color: @accent;
          text-color: @bg;
        }

        element urgent {
          background-color: @urgent;
        }

        element-icon {
          size: 24;
          margin: 0 8 0 0;
        }

        element-text {
          highlight: bold;
        }
      '';
      force = true;
    };
  };
}
