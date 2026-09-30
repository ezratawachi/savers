#!/bin/bash
# The quick way to see the Swift app in the simulator, with made-up data (see SAVERS/App/Scenario.swift).
#
#   probar.sh hoja [escenario[:pantallas] ...]   builds, opens each scenario and joins the captures in one image
#   probar.sh abrir <escenario>                  builds and leaves the app open in that scenario, to try it with AXe
#   probar.sh ui                                 what's on screen as text: one line per element
#   probar.sh tocar "<etiqueta>"                 taps the element with that accessibility label
#   probar.sh real                               opens the app again with its real data
#
# Scenarios: manana abiertas hechas dia-completo shabbat sin-savers historial (all of them if none is given).
# "hechas:2" also scrolls down and captures a second screen. --sin-build skips building.
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
HERE=$(cd "$(dirname "$0")/.." && pwd)
UDID=$(cat "$HERE/.sim-id")
BUNDLE=com.ezratawachi.savers
APP="$HERE/../swift-build/Build/Products/Debug-iphonesimulator/SAVERS.app"
OUT="$HERE/../swift-build/probar"
ALL=(manana abiertas hechas dia-completo shabbat sin-savers historial)

build() {
  xcrun simctl boot "$UDID" 2>/dev/null || true
  if ! xcodebuild -project "$HERE/SAVERS.xcodeproj" -scheme SAVERS -configuration Debug -destination "id=$UDID" \
       -derivedDataPath "$HERE/../swift-build" -quiet build 2>&1 | grep -E "error:" ; then :; fi
  [ "${PIPESTATUS[0]}" = 0 ] || { echo "falló la compilación"; exit 1; }
  xcrun simctl install "$UDID" "$APP"
}

# Opens the app in a scenario (or with its real data when none) and waits for it to settle.
launch() {
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  if [ -n "${1:-}" ]; then xcrun simctl launch "$UDID" "$BUNDLE" -escenario "$1" >/dev/null
  else xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null; fi
  sleep 2.5
}

cmd=${1:-hoja}; shift || true
nobuild=0
args=()
for a in "$@"; do [ "$a" = "--sin-build" ] && nobuild=1 || args+=("$a"); done

case "$cmd" in
  hoja)
    [ $nobuild = 1 ] || build
    [ ${#args[@]} -gt 0 ] || args=("${ALL[@]}")
    rm -rf "$OUT"; mkdir -p "$OUT"
    shots=()
    for spec in "${args[@]}"; do
      name=${spec%%:*}; screens=1
      [ "$spec" != "$name" ] && screens=${spec#*:}
      launch "$name"
      for ((i = 1; i <= screens; i++)); do
        if [ $i -gt 1 ]; then axe swipe --start-x 340 --start-y 600 --end-x 340 --end-y 180 --udid "$UDID" >/dev/null; sleep 1; fi
        f="$OUT/$name-$i.png"
        xcrun simctl io "$UDID" screenshot "$f" >/dev/null 2>&1
        shots+=("$f")
      done
    done
    python3 "$HERE/tools/hoja.py" "$OUT/hoja.png" "${shots[@]}"
    launch ""
    echo "$OUT/hoja.png"
    ;;
  abrir)
    [ $nobuild = 1 ] || build
    launch "${args[0]:?falta el escenario}"
    ;;
  tocar)
    # AXe's default tap doesn't reach SwiftUI buttons here; a physical touch does.
    axe tap --label "${args[0]:?falta la etiqueta}" --tap-style physical --wait-timeout 3 --udid "$UDID" >/dev/null
    sleep 0.8
    ;;
  ui)
    axe describe-ui --udid "$UDID" | python3 "$HERE/tools/ui.py"
    ;;
  real)
    launch ""
    ;;
  *)
    sed -n 2,12p "$0"; exit 1
    ;;
esac
