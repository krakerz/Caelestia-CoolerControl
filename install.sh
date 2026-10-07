#!/bin/sh
# Links this checkout as the "caelestia-coolercontrol" Quickshell config and seeds the user config.
set -e
here=$(cd "$(dirname "$0")" && pwd)
qs_dir="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/caelestia-coolercontrol"
mkdir -p "$qs_dir" "$cfg_dir"
ln -sfn "$here" "$qs_dir/caelestia-coolercontrol"
if [ ! -e "$cfg_dir/config.json" ]; then
    cp "$here/config.example.json" "$cfg_dir/config.json"
    chmod 600 "$cfg_dir/config.json"
fi
echo "Installed. Edit $cfg_dir/config.json, then run: qs -c caelestia-coolercontrol"
