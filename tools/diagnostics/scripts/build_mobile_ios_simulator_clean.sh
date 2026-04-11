#!/bin/zsh
setopt errexit nounset pipefail

src="/Users/jorgeluispriegocruz/Documents/SAO/frontend_flutter/sao_windows"
tmp="/tmp/sao_windows_ios_build_clean"

rm -rf "$tmp"
mkdir -p "$tmp"

rsync -a --delete \
  --exclude build \
  --exclude .dart_tool \
  --exclude ios/Pods \
  --exclude ios/Runner.xcworkspace \
  --exclude ios/Flutter/ephemeral \
  "$src/" "$tmp/"

cd "$tmp"
flutter clean
flutter pub get
flutter build ios --simulator --no-codesign

du -sh "$tmp/build/ios/iphonesimulator" 2>/dev/null || true