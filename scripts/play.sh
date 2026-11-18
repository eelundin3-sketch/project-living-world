#!/bin/sh
# Starts Project Solo from this checkout with Godot 4.6 stable.
#   scripts/play.sh            find Godot 4.6 and run the game
#   scripts/play.sh --check    only report which Godot it would use
# Set GODOT_BIN to a specific Godot 4.6 program to skip the search.
cd "$(dirname "$0")/.." || exit 1

is_46() {
  [ -x "$1" ] && "$1" --version 2>/dev/null | grep -q '^4\.6\.'
}

find_godot() {
  if [ -n "$GODOT_BIN" ]; then
    if is_46 "$GODOT_BIN"; then echo "$GODOT_BIN"; return 0; fi
    echo "GODOT_BIN is set to '$GODOT_BIN', which is not Godot 4.6." >&2
    return 1
  fi
  for candidate in \
    "/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Downloads/Godot.app/Contents/MacOS/Godot" \
    "$HOME/Applications/Godot 4.6/Godot.app/Contents/MacOS/Godot" \
    "$(command -v godot 2>/dev/null)" \
    "$(command -v godot4 2>/dev/null)"; do
    if [ -n "$candidate" ] && is_46 "$candidate"; then echo "$candidate"; return 0; fi
  done
  return 1
}

GODOT="$(find_godot)" || {
  cat >&2 <<'MSG'
Could not find Godot 4.6 stable (the standard edition).
Download it from https://godotengine.org/download/archive/4.6-stable/ , then either put it in
/Applications or run:  GODOT_BIN=/path/to/Godot scripts/play.sh
(Newer Godot versions may upgrade the project files, so 4.6 is required.)
MSG
  exit 1
}

if [ "$1" = "--check" ]; then
  echo "Would run: $GODOT --path $(pwd)"
  exit 0
fi
exec "$GODOT" --path .
