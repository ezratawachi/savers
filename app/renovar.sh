#!/bin/bash
# Keeps the SAVERS iPhone app opening. A free Apple ID signs apps for only 7 days, so launchd runs this every hour
# (~/Library/LaunchAgents/com.ezratawachi.savers-renovar.plist) and, once 2 days or less are left, it builds with a
# fresh signature and installs it on the iPhone, over Wi-Fi or the cable. The web inside doesn't change: only the
# signature. If the iPhone can't be reached for a day, it keeps trying every hour and the Mac shows a notice.
# `renovar.sh ya` renews right away.
set -u
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
HERE=$(cd "$(dirname "$0")" && pwd)
DEVICE=00008110-000155E002C2801E
APP_ID=YQ4GUVW7H7.com.ezratawachi.savers
APP="$HERE/ios/DerivedData/Build/Products/Debug-iphoneos/App.app"
PROFILES="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
STATE="$HOME/Library/Application Support/savers-renovar"
DAY=86400

mkdir -p "$STATE"
now=$(date +%s)
installed=$(cat "$STATE/vence" 2>/dev/null || echo 0)   # when the signature on the iPhone expires (epoch)
if [ "${1:-}" != "ya" ] && [ $((installed - now)) -gt $((2 * DAY)) ]; then exit 0; fi

notify() { osascript -e "display notification \"$1\" with title \"SAVERS\"" >/dev/null 2>&1; }
expiry() { security cms -D -i "$1" 2>/dev/null | plutil -extract ExpirationDate raw -o - - 2>/dev/null; }
epoch() { date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null || echo 0; }
app_id() { security cms -D -i "$1" 2>/dev/null | plutil -extract Entitlements.application-identifier raw -o - - 2>/dev/null; }

echo "$(date '+%F %T') renovando (la del iPhone vence $(date -r "$installed" '+%F %T' 2>/dev/null))"

# Xcode keeps reusing its local profile until it expires; removing an old one makes it ask Apple for a new 7-day one.
# A fresh profile from an earlier try whose install failed is kept, so hourly retries don't make a new one each time.
for p in "$PROFILES"/*.mobileprovision; do
  [ -f "$p" ] && [ "$(app_id "$p")" = "$APP_ID" ] || continue
  if [ $(( $(epoch "$(expiry "$p")") - now )) -le $((2 * DAY)) ]; then rm -f "$p"; fi
done

cd "$HERE/ios/App" || exit 1
if ! xcodebuild -project App.xcodeproj -scheme App -configuration Debug -destination "id=$DEVICE" \
     -derivedDataPath ../DerivedData -allowProvisioningUpdates -quiet build; then
  echo "falló la compilación"
  notify "No se pudo firmar SAVERS. Abre Xcode y revisa tu Apple ID en Settings › Accounts."
  exit 1
fi
until=$(epoch "$(expiry "$APP/embedded.mobileprovision")")

if ! xcrun devicectl device install app --device "$DEVICE" "$APP" >/dev/null 2>&1; then
  echo "no se encontró el iPhone"
  if [ $((installed - now)) -lt $DAY ]; then
    notify "Para renovar SAVERS, pon el iPhone en la misma Wi-Fi que la Mac (o conéctalo con cable) y desbloquéalo."
  fi
  exit 1
fi

echo "$until" > "$STATE/vence"
echo "instalada, vence $(date -r "$until" '+%F %T')"
notify "SAVERS renovada en el iPhone hasta el $(date -r "$until" '+%d/%m')."
