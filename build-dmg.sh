#!/bin/bash
set -euo pipefail

APP_NAME="FreeTypeless"
BUNDLE_ID="com.henry4ai.freetypeless"
SIGN_IDENTITY="FreeTypeless Dev"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_BUNDLE="$PROJECT_DIR/dist/${APP_NAME}.app"
DMG_PATH="$PROJECT_DIR/dist/${APP_NAME}.dmg"

# Ensure a stable self-signed certificate exists (prevents TCC permission reset)
CERT_CHECK=$(security find-identity -p codesigning 2>/dev/null | grep "$SIGN_IDENTITY" || true)
if [ -z "$CERT_CHECK" ]; then
    echo "==> Creating self-signed certificate '$SIGN_IDENTITY'..."

    # Generate self-signed certificate with openssl
    openssl req -x509 -newkey rsa:2048 \
        -keyout /tmp/ft-key.pem -out /tmp/ft-cert.pem \
        -days 3650 -nodes \
        -subj "/CN=$SIGN_IDENTITY" \
        -addext "keyUsage=digitalSignature" \
        -addext "extendedKeyUsage=codeSigning" 2>/dev/null

    # Package as PKCS12 (use legacy algorithms for macOS Keychain compatibility)
    openssl pkcs12 -export \
        -out /tmp/ft-cert.p12 \
        -inkey /tmp/ft-key.pem -in /tmp/ft-cert.pem \
        -passout pass:temp123 \
        -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1

    # Import into login keychain
    KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
    if [ ! -f "$KEYCHAIN" ]; then
        KEYCHAIN="$HOME/Library/Keychains/login.keychain"
    fi
    security import /tmp/ft-cert.p12 -k "$KEYCHAIN" -P temp123 -T /usr/bin/codesign || true

    # Allow codesign to use the key without prompting
    security set-key-partition-list -S apple-tool:,apple: -s -k "" "$KEYCHAIN" 2>/dev/null || true

    rm -f /tmp/ft-key.pem /tmp/ft-cert.pem /tmp/ft-cert.p12

    echo "    Certificate '$SIGN_IDENTITY' created."
    echo "    NOTE: For full trust, open Keychain Access > '$SIGN_IDENTITY' > Trust > Code Signing: Always Trust"
    echo ""
else
    echo "==> Certificate '$SIGN_IDENTITY' found."
fi

echo "==> Cleaning previous build..."
rm -rf "$PROJECT_DIR/dist"
mkdir -p "$PROJECT_DIR/dist"

# 1. Build release binary
echo "==> Building release binary..."
cd "$PROJECT_DIR"
swift build -c release

# 2. Create .app bundle structure
echo "==> Creating app bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. Copy executable
cp "$BUILD_DIR/SwiftTypeless" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

# 4. Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# 5. Copy resources (audio, icon)
cp -R "$PROJECT_DIR/Resources/audio" "$APP_BUNDLE/Contents/Resources/"
cp "$PROJECT_DIR/Resources/hands.png" "$APP_BUNDLE/Contents/Resources/"

# Also copy SPM-bundled resources if they exist
if [ -d "$BUILD_DIR/SwiftTypeless_SwiftTypeless.bundle" ]; then
    cp -R "$BUILD_DIR/SwiftTypeless_SwiftTypeless.bundle" "$APP_BUNDLE/Contents/Resources/"
fi

# 6. Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# 7. Create app icon from hands.png (if iconutil is available)
if command -v iconutil &> /dev/null && command -v sips &> /dev/null; then
    echo "==> Generating app icon..."
    ICONSET="$PROJECT_DIR/dist/AppIcon.iconset"
    mkdir -p "$ICONSET"
    SRC_ICON="$PROJECT_DIR/Resources/hands.png"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size "$SRC_ICON" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null 2>&1
        double=$((size * 2))
        sips -z $double $double "$SRC_ICON" --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null 2>&1
    done
    iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET"
    # Add icon reference to Info.plist
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP_BUNDLE/Contents/Info.plist"
fi

# 8. Code sign with entitlements (use stable certificate)
echo "==> Code signing..."
# Find certificate hash (works even if not trusted — stable hash is what matters for TCC)
CERT_HASH=$(security find-identity -p codesigning 2>/dev/null | grep "$SIGN_IDENTITY" | head -1 | awk '{print $2}')
if [ -n "$CERT_HASH" ]; then
    echo "    Using certificate: $SIGN_IDENTITY ($CERT_HASH)"
    codesign --force --deep --sign "$CERT_HASH" \
        --entitlements "$PROJECT_DIR/Resources/SwiftTypeless.entitlements" \
        "$APP_BUNDLE"
else
    echo "    WARNING: Certificate not found, using ad-hoc signing (TCC permissions will reset each build)"
    codesign --force --deep --sign - \
        --entitlements "$PROJECT_DIR/Resources/SwiftTypeless.entitlements" \
        "$APP_BUNDLE"
fi

# 9. Create DMG with Applications shortcut
echo "==> Creating DMG..."
DMG_STAGING="$PROJECT_DIR/dist/dmg-staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_BUNDLE" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

# Generate background image
echo "==> Generating DMG background..."
DMG_BG="$PROJECT_DIR/Resources/dmg-background.png"
python3 "$PROJECT_DIR/scripts/gen-dmg-bg.py" "$DMG_BG"

# Detach any previously mounted volumes with the same name
hdiutil detach "/Volumes/$APP_NAME" 2>/dev/null || true

# Create a temporary read-write DMG (extra space for background)
DMG_TMP="$PROJECT_DIR/dist/${APP_NAME}-tmp.dmg"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDRW \
    -size 20m \
    "$DMG_TMP"

# Mount it to set Finder view options and background
MOUNT_DIR="/Volumes/$APP_NAME"
hdiutil attach -readwrite -noverify "$DMG_TMP" -mountpoint "$MOUNT_DIR"
echo "    Mounted at: $MOUNT_DIR"

# Copy background image into hidden folder inside the DMG
mkdir -p "$MOUNT_DIR/.background"
cp "$DMG_BG" "$MOUNT_DIR/.background/bg.png"

# Set Finder window appearance via AppleScript
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 720, 400}
        set opts to icon view options of container window
        set icon size of opts to 80
        set arrangement of opts to not arranged
        set background picture of opts to file ".background:bg.png"
        set position of item "${APP_NAME}.app" of container window to {130, 140}
        set position of item "Applications" of container window to {390, 140}
        close
        open
        update without registering applications
    end tell
end tell
APPLESCRIPT

# Wait for Finder to write .DS_Store
sleep 2
sync

# Unmount, convert to compressed read-only DMG
hdiutil detach "$MOUNT_DIR" -quiet
hdiutil convert "$DMG_TMP" -format UDZO -o "$DMG_PATH"
rm -f "$DMG_TMP"
rm -rf "$DMG_STAGING"

echo ""
echo "==> Done!"
echo "    App:  $APP_BUNDLE"
echo "    DMG:  $DMG_PATH"
