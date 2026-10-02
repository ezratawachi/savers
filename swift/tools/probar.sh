#!/bin/bash
# The quick way to see the Swift app in the simulator, with made-up data (see SAVERS/App/Scenario.swift).
#
#   probar.sh hoja [escenario[:pantallas] ...]   builds, opens each scenario and joins the captures in one image
#   probar.sh abrir <escenario>                  builds and leaves the app open in that scenario, to try it with AXe
#   probar.sh ui                                 what's on screen as text: one line per element
#   probar.sh tocar "<etiqueta>"                 taps the element with that accessibility label
#   probar.sh real                               opens the app again with its real data
#
# Scenarios: manana abiertas hechas dia-completo shabbat sin-savers historial ajustes (all of them if none is given).
# "hechas:2" also scrolls down and captures a second screen. --sin-build skips building.
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
HERE=$(cd "$(dirname "$0")/.." && pwd)
UDID=$(cat "$HERE/.sim-id")
BUNDLE=com.ezratawachi.savers
APP="$HERE/../swift-build/Build/Products/Debug-iphonesimulator/SAVERS.app"
OUT="$HERE/../swift-build/probar"
ALL=(manana abiertas hechas dia-completo shabbat sin-savers historial ajustes)

build() {
  xcrun simctl boot "$UDID" 2>/dev/null || true
  if ! xcodebuild -project "$HERE/SAVERS.xcodeproj" -scheme SAVERS -configuration Debug -destination "id=$UDID" \
       -derivedDataPath "$HERE/../swift-build" -quiet build 2>&1 | grep -E "error:" ; then :; fi
  [ "${PIPESTATUS[0]}" = 0 ] || { echo "falló la compilación"; exit 1; }
  xcrun simctl install "$UDID" "$APP"
}

# Waits until the app is drawn and still, however long the simulator takes: first its accessibility tree
# has to show the app (Sunling) with something in it (the home screen and the launch screen don't), then two captures
# in a row have to match, once the fade-in is over. The last capture stays in $SHOT.
SHOT="$OUT/.ultima.png"
settle() {
  local prev="" sum tree up=0
  mkdir -p "$OUT"
  for _ in $(seq 1 40); do
    sleep 0.3
    if [ $up = 0 ]; then
      tree=$(axe describe-ui --udid "$UDID" 2>/dev/null | python3 "$HERE/tools/ui.py" 2>/dev/null) || tree=""
      [[ "$(head -1 <<<"$tree")" == *"'Sunling'"* ]] && [ "$(grep -c . <<<"$tree")" -gt 3 ] || continue
      up=1
    fi
    xcrun simctl io "$UDID" screenshot "$SHOT" >/dev/null 2>&1 || continue
    sum=$(md5 -q "$SHOT")
    [ "$sum" = "$prev" ] && return
    prev=$sum
  done
}

# Opens the app in a scenario (or with its real data when none) and waits for it to settle.
launch() {
  xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
  if [ -n "${1:-}" ]; then xcrun simctl launch "$UDID" "$BUNDLE" -escenario "$1" >/dev/null
  else xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null; fi
  settle
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
        if [ $i -gt 1 ]; then axe swipe --start-x 340 --start-y 600 --end-x 340 --end-y 180 --udid "$UDID" >/dev/null; settle; fi
        f="$OUT/$name-$i.png"
        cp "$SHOT" "$f"
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
    # Xcode 27 drops the first gesture of a fresh AXe connection until its touchscreen wakes up
    # (AXe issue #71); waiting 500 ms first lets it land. A physical touch doesn't land at all there.
    AXE_HID_STABILIZATION_MS=500 axe tap --label "${args[0]:?falta la etiqueta}" --tap-style simulator \
      --wait-timeout 3 --udid "$UDID" >/dev/null
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
