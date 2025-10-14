#!/usr/bin/env bash
# Toggle the enabled state of the inbuilt "AT Translated Set 2 keyboard"

set -e

# Find the input device path for the internal keyboard
device_path=$(grep -l 'AT Translated Set 2 keyboard' /sys/class/input/*/device/name | head -n1)
if [[ -z "$device_path" ]]; then
  echo "Internal keyboard not found!" >&2
  exit 1
fi

enabled_file="${device_path%/name}/enabled"

if [[ ! -w "$enabled_file" ]]; then
  echo "Cannot write to $enabled_file (need root?)" >&2
  exit 1
fi

current=$(cat "$enabled_file")
if [[ "$current" == "1" ]]; then
  echo 0 > "$enabled_file"
  echo "Internal keyboard disabled."
else
  echo 1 > "$enabled_file"
  echo "Internal keyboard enabled."
fi
