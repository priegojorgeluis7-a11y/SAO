#!/bin/zsh
setopt errexit nounset pipefail

src="/Users/jorgeluispriegocruz/Documents/SAO/desktop_flutter/sao_desktop"
tmp="/tmp/sao_desktop_build_clean"
output_dir="$src/build/macos/Build/Products/Release"
app_name="sao_desktop.app"
backend_url="${SAO_BACKEND_URL:-https://sao-api-fjzra25vya-uc.a.run.app}"

rm -rf "$tmp"
mkdir -p "$tmp"

rsync -a --delete \
  --exclude build \
  --exclude .dart_tool \
  --exclude macos/Pods \
  --exclude macos/Flutter/ephemeral \
  "$src/" "$tmp/"

cd "$tmp"
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build macos --dart-define="SAO_BACKEND_URL=$backend_url"

mkdir -p "$output_dir"
rm -rf "$output_dir/$app_name"
ditto "build/macos/Build/Products/Release/$app_name" "$output_dir/$app_name"

du -sh "$output_dir/$app_name"