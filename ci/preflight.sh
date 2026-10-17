#!/bin/bash
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This workflow requires a macOS build machine with Xcode.' >&2
  exit 1
fi
test -f RentShare.xcodeproj/project.pbxproj
test -f RentShare.xcodeproj/xcshareddata/xcschemes/RentShare.xcscheme
plutil -lint RentShare.xcodeproj/project.pbxproj RentShare/Info.plist RentShare/Resources/PrivacyInfo.xcprivacy
for lang in uz ru en; do
  plutil -lint "RentShare/Resources/$lang.lproj/InfoPlist.strings"
done
xcodebuild -version
sdk="$(xcrun --sdk iphoneos --show-sdk-version)"
if (( ${sdk%%.*} < 26 )); then echo 'Select Xcode with iOS SDK 26 or newer.' >&2; exit 1; fi
xcodebuild -list -project RentShare.xcodeproj
