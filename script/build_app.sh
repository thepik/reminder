#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Reminder"
BUNDLE_ID="com.thepik.Reminder"
VERSION="1.0"
BUILD_NUMBER="1"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="$ROOT_DIR/build/objc-release"
BUILD_APP="$BUILD_ROOT/$APP_NAME.app"
OBJECTS_DIR="$BUILD_ROOT/Objects"
CONTENTS="$BUILD_APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
DIST_DIR="$ROOT_DIR/dist"
DIST_APP="$DIST_DIR/$APP_NAME.app"
ICONSET="$ROOT_DIR/ReminderObjC/Resources/AppIcon.iconset"

SOURCES=(
  "$ROOT_DIR/ReminderObjC/Sources/main.m"
  "$ROOT_DIR/ReminderObjC/Sources/AppDelegate.m"
  "$ROOT_DIR/ReminderObjC/Sources/Models/ReminderCategory.m"
  "$ROOT_DIR/ReminderObjC/Sources/Models/ReminderItem.m"
  "$ROOT_DIR/ReminderObjC/Sources/Store/ReminderStore.m"
  "$ROOT_DIR/ReminderObjC/Sources/Theme/ReminderTheme.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/CategoryTabView.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/InputBarView.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/ReminderRowView.m"
  "$ROOT_DIR/ReminderObjC/Sources/Views/ReminderWindowController.m"
)

rm -rf "$BUILD_APP"
rm -rf "$OBJECTS_DIR"
mkdir -p "$MACOS" "$RESOURCES" "$DIST_DIR" "$OBJECTS_DIR"

echo "Compiling $APP_NAME..."
OBJECTS=()
for source in "${SOURCES[@]}"; do
  object="$OBJECTS_DIR/$(basename "${source%.m}").o"
  echo "  $(basename "$source")"
  clang \
    -fobjc-arc \
    -O0 \
    -Wall \
    -Wextra \
    -Werror \
    -mmacosx-version-min=15.0 \
    -c "$source" \
    -o "$object"
  OBJECTS+=("$object")
done

echo "Linking $APP_NAME..."
clang \
  -mmacosx-version-min=15.0 \
  -framework Cocoa \
  "${OBJECTS[@]}" \
  -o "$MACOS/$APP_NAME"

echo "Preparing app bundle..."
strip -x "$MACOS/$APP_NAME" || true
cp "$ICONSET/icon_512x512@2x.png" "$RESOURCES/AppIcon.png"

plutil -create xml1 "$CONTENTS/Info.plist"
plutil -insert CFBundleDevelopmentRegion -string en "$CONTENTS/Info.plist"
plutil -insert CFBundleExecutable -string "$APP_NAME" "$CONTENTS/Info.plist"
plutil -insert CFBundleIconFile -string AppIcon.png "$CONTENTS/Info.plist"
plutil -insert CFBundleIdentifier -string "$BUNDLE_ID" "$CONTENTS/Info.plist"
plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "$CONTENTS/Info.plist"
plutil -insert CFBundleName -string "$APP_NAME" "$CONTENTS/Info.plist"
plutil -insert CFBundlePackageType -string APPL "$CONTENTS/Info.plist"
plutil -insert CFBundleShortVersionString -string "$VERSION" "$CONTENTS/Info.plist"
plutil -insert CFBundleVersion -string "$BUILD_NUMBER" "$CONTENTS/Info.plist"
plutil -insert LSMinimumSystemVersion -string 15.0 "$CONTENTS/Info.plist"
plutil -insert NSHumanReadableCopyright -string "" "$CONTENTS/Info.plist"
plutil -insert NSPrincipalClass -string NSApplication "$CONTENTS/Info.plist"
printf "APPL????" > "$CONTENTS/PkgInfo"

echo "Signing app..."
xattr -cr "$BUILD_APP"
codesign --force --deep --sign "$SIGN_IDENTITY" "$BUILD_APP"
codesign --verify --deep --strict --verbose=2 "$BUILD_APP"

echo "Copying release app..."
rm -rf "$DIST_APP"
ditto --noextattr "$BUILD_APP" "$DIST_APP"
codesign --verify --deep --strict --verbose=2 "$DIST_APP"

echo "Release app is ready: $DIST_APP"
du -sh "$DIST_APP"
