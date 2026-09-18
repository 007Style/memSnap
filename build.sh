#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# build.sh  —  memSnap  release builder
# ─────────────────────────────────────────────────────────────────────────────
# Usage:
#   ./build.sh           →  Build, commit, tag, push, create GitHub release
#   ./build.sh --local   →  Build + create DMG only (no git operations)
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
APP_NAME="memSnap"
BUNDLE_ID="com.daneyand.memSnap"
VERSION="1.0.0"
BUILD_NUMBER="1"
MIN_MACOS="13.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"
BUILD_DIR="$ROOT/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

LOCAL_ONLY=false
[[ "${1:-}" == "--local" ]] && LOCAL_ONLY=true

echo "🧠 $APP_NAME v$VERSION — release build"

# ── Swift build ───────────────────────────────────────────────────────────────
echo "── Compiling…"
cd "$ROOT"
swift build -c release

BINARY=".build/release/$APP_NAME"
[[ -f "$BINARY" ]] || { echo "❌  Binary not found: $BINARY"; exit 1; }

# ── Assemble .app bundle ──────────────────────────────────────────────────────
echo "── Assembling .app bundle…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
</dict>
</plist>
PLIST

# Generate .icns from SVG if swift script present; otherwise use placeholder
ICON_SVG="$ROOT/Sources/$APP_NAME/Assets/icon.svg"
ICNS_PATH="$APP_BUNDLE/Contents/Resources/$APP_NAME.icns"
if [[ -f "$ROOT/scripts/svg2icns.swift" && -f "$ICON_SVG" ]]; then
    echo "── Generating .icns from SVG…"
    swift "$ROOT/scripts/svg2icns.swift" "$ICON_SVG" "$ICNS_PATH"
    cat >> "$APP_BUNDLE/Contents/Info.plist.tmp" <<'EOF' 2>/dev/null || true
EOF
    # Inject CFBundleIconFile into plist (append before </dict>)
    sed -i '' 's|</dict>|    <key>CFBundleIconFile</key><string>'"$APP_NAME"'</string>\n</dict>|' \
        "$APP_BUNDLE/Contents/Info.plist"
fi

# ── Code-sign ────────────────────────────────────────────────────────────────
echo "── Code-signing…"
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep -o '"[^"]*"' | head -1 | tr -d '"' || true)
[[ -z "$IDENTITY" ]] && IDENTITY="-"
echo "   Identity: ${IDENTITY:--  (ad-hoc)}"
codesign --force --deep --sign "$IDENTITY" "$APP_BUNDLE" 2>/dev/null || \
    codesign --force --deep --sign - "$APP_BUNDLE"

# ── DMG (installer-style: /Applications symlink + AppleScript window) ────────
echo "── Creating installer DMG…"
mkdir -p "$BUILD_DIR"
rm -f "$DMG_PATH"

DMG_STAGING="$BUILD_DIR/dmg-staging"
TMP_DMG="$BUILD_DIR/tmp-rw.dmg"
VOLUME_NAME="$APP_NAME $VERSION"

rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# Copy app bundle and add /Applications drag-target symlink
cp -R "$APP_BUNDLE" "$DMG_STAGING/$APP_NAME.app"
ln -s /Applications "$DMG_STAGING/Applications"

# Add README.txt with install instructions
cat > "$DMG_STAGING/README.txt" << 'README'
memSnap — Memory Pressure Monitor for macOS
============================================
Requires macOS 13 (Ventura) or later.

INSTALL:
  Drag memSnap.app into the Applications folder.

FIRST RUN:
  macOS may show a security prompt since the app is not notarised.
  Right-click the app and choose "Open", then confirm.

  To enable process Focus actions, grant Accessibility access in:
  System Settings → Privacy & Security → Accessibility → memSnap

NOTIFICATIONS:
  memSnap will request notification permission on first launch.

UNINSTALL:
  Drag memSnap.app from Applications to the Trash.
  Preferences: ~/Library/Preferences/com.daneyand.memSnap.plist

---
From the minds of Daneyand & IBM Bob
README

# Step 1: Create writable intermediate DMG from staging folder
rm -f "$TMP_DMG"
hdiutil create \
    -volname  "$VOLUME_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "$TMP_DMG" > /dev/null

# Step 2: Mount the writable DMG
DEVICE="$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DMG" \
    | awk '/Apple_HFS/ { print $1 }')"
sleep 1

# Step 3: Style the Finder window with AppleScript
osascript << APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, 720, 420}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 96
    set position of item "$APP_NAME.app"  of container window to {170, 145}
    set position of item "Applications"   of container window to {390, 145}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
APPLESCRIPT

# Step 4: Unmount and convert to compressed read-only DMG
hdiutil detach "$DEVICE" > /dev/null
sleep 1

hdiutil convert "$TMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH" > /dev/null

# Clean up staging
rm -f "$TMP_DMG"
rm -rf "$DMG_STAGING"

echo ""
echo "✅  $DMG_NAME created in build/"
echo "    Size: $(du -sh "$DMG_PATH" | cut -f1)"
echo "    Install: open DMG and drag $APP_NAME.app → Applications"

if $LOCAL_ONLY; then
    echo ""
    echo "──  --local flag set: skipping git operations."
    exit 0
fi

# ── Git commit + tag ──────────────────────────────────────────────────────────
echo ""
echo "── Committing DMG…"
cd "$ROOT"
git add "build/$DMG_NAME"
git commit -m "build: $APP_NAME v$VERSION release DMG" || true

TAG="v$VERSION"
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "   Tag $TAG already exists — skipping tag creation."
else
    git tag -a "$TAG" -m "$APP_NAME $TAG"
    echo "   Tagged: $TAG"
fi

git push origin HEAD --follow-tags

# ── GitHub release ────────────────────────────────────────────────────────────
echo ""
echo "── Creating GitHub release $TAG..."
RELEASE_NOTES="## $APP_NAME v$VERSION

Native macOS menu-bar memory pressure monitor.

### Features
- Real-time kernel memory pressure monitoring (normal / elevated / warning / critical / swap)
- Segmented bar tray icon (wired / compressed / app / free)
- Top-8 process list with kill & focus actions
- Smart notifications with duration-threshold de-bouncing
- Memory trend prediction (minutes until critical)
- Auto-kill rules for runaway processes
- 24-hour hourly pressure heatmap
- CSV export & cache purge

### Install
Drag \`$APP_NAME.app\` to Applications. Grant Notifications permission on first launch.

---
*From the minds of Daneyand & IBM Bob*"

gh release create "$TAG" "$DMG_PATH" \
    --title "$APP_NAME $TAG" \
    --notes "$RELEASE_NOTES" \
    --latest

echo ""
echo "🎉  GitHub release $TAG published with $DMG_NAME attached."
