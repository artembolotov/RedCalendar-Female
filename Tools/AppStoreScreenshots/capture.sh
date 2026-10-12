#!/bin/zsh
#
# App Store screenshots from mock data. See README.md next to this file.
#
#   Tools/AppStoreScreenshots/capture.sh            # Russian
#   Tools/AppStoreScreenshots/capture.sh ru en      # both languages
#   SCENES="calendar tags" Tools/AppStoreScreenshots/capture.sh
#
# The working tree is touched only for the length of the build: the hooks and ScreenshotMode.swift
# go in, the app is built, and both come out again before anything is captured — also when the
# build fails or the script is interrupted.

set -euo pipefail

HERE=${0:A:h}
ROOT=$(git -C "$HERE" rev-parse --show-toplevel)
LANGS=(${@:-ru})
SCENE_LIST=(${=SCENES:-calendar period tags comment statistics settings})
DEVICE_NAME=${DEVICE_NAME:-"iPhone 18 Pro"}
ACCENT=${ACCENT:-coral}
OUTPUT=${OUTPUT:-$HERE/Output}
DERIVED_DATA=${TMPDIR:-/tmp}/redcalendar-screenshots-dd
BUNDLE_ID=ru.artembolotov.RedCalendar-Woman
TARGET_FILE=$ROOT/RedCalendar-Female/App/ScreenshotMode.swift
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}

UDID=$(xcrun simctl list devices available | grep -E "^ +$DEVICE_NAME \(" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
if [[ -z $UDID ]]; then
    print -u2 "No available simulator named \"$DEVICE_NAME\"."
    exit 1
fi

# MARK: - Hooks in, build, hooks out

hooks_out() {
    rm -f "$TARGET_FILE"
    if git -C "$ROOT" apply -R --check "$HERE/hooks.patch" 2>/dev/null; then
        git -C "$ROOT" apply -R "$HERE/hooks.patch"
    fi
}

if ! git -C "$ROOT" apply --check "$HERE/hooks.patch"; then
    print -u2 "hooks.patch no longer applies — the code around a hook has changed. See README.md, \"If the patch stops applying\"."
    exit 1
fi

trap hooks_out EXIT INT TERM
git -C "$ROOT" apply "$HERE/hooks.patch"
cp "$HERE/ScreenshotMode.swift" "$TARGET_FILE"

print "Building for $DEVICE_NAME ($UDID)…"
xcodebuild -quiet \
    -project "$ROOT/RedCalendar-Female.xcodeproj" \
    -scheme RedCalendar-Staging -configuration Debug-Staging \
    -destination "id=$UDID" -derivedDataPath "$DERIVED_DATA" \
    build

hooks_out
trap - EXIT INT TERM
print "Build done, working tree restored."

APP=$DERIVED_DATA/Build/Products/Debug-Staging-iphonesimulator/RedCalendar-Female.app

# MARK: - Simulator

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
xcrun simctl status_bar "$UDID" override \
    --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
xcrun simctl install "$UDID" "$APP"

launch() { # scene lang
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE_ID" \
        -ScreenshotMode YES -ScreenshotScene "$1" -ScreenshotAccent "$ACCENT" \
        -AppleLanguages "($2)" -AppleLocale "$3" >/dev/null
}

# The first launch after an install is noticeably slower than the rest; let it be a throwaway.
xcrun simctl ui "$UDID" appearance light
launch calendar ru ru_RU
sleep 8

# MARK: - Capture

for lang in $LANGS; do
    case $lang in
        ru) locale=ru_RU ;;
        en) locale=en_US ;;
        *) locale=$lang ;;
    esac

    index=0
    for scene in $SCENE_LIST; do
        index=$((index + 1))
        name=$(printf "%02d-%s.png" $index $scene)

        xcrun simctl ui "$UDID" appearance light
        launch "$scene" "$lang" "$locale"
        # Selection lands 1.5s after launch and a sheet ~1.2s after that.
        case $scene in
            tags|comment|statistics|settings) sleep 9 ;;
            *) sleep 7 ;;
        esac

        for appearance in light dark; do
            mkdir -p "$OUTPUT/$lang/$appearance"
            xcrun simctl ui "$UDID" appearance $appearance
            sleep 2
            xcrun simctl io "$UDID" screenshot "$OUTPUT/$lang/$appearance/$name" >/dev/null 2>&1
            print "  $lang/$appearance/$name"
        done
    done
done

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" clear
print "Done: $OUTPUT"
