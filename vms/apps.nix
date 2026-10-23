# The user's own apps (NoX's catalog has free software only): unfree ones
# are allowed by name in the VMs that list them (store group prop or own
# image).
{
  nox.apps = {
    slack = {
      package = "slack";
      name = "Slack";
      genericName = "Slack";
      icon = "slack";
      categories = [
        "Network"
        "InstantMessaging"
        "Chat"
      ];
      mimeType = [ "x-scheme-handler/slack" ];
      unfree = true;
    };
    chrome = {
      package = "google-chrome";
      name = "Chrome";
      genericName = "Web Browser";
      binary = "google-chrome-stable";
      icon = "google-chrome";
      categories = [
        "Network"
        "WebBrowser"
      ];
      unfree = true;
    };
    postman = {
      package = "postman";
      name = "Postman";
      genericName = "API Client";
      icon = "postman";
      categories = [
        "Development"
        "Utility"
      ];
      unfree = true;
    };
  };
}
