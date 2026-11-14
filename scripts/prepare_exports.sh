#!/bin/sh
# Usage: scripts/prepare_exports.sh /path/to/Godot_v4.6-stable_export_templates.tpz
set -eu
cd "$(dirname "$0")/.."
mkdir -p .godot/export_templates
unzip -j -o "$1" 'templates/windows_*x86_64*' 'templates/linux_*.x86_64' templates/macos.zip -d .godot/export_templates
printf '%s\n' 'For macOS export, also install this .tpz through Godot: Editor > Manage Export Templates.'
