#!/bin/bash
set -euo pipefail
# Set IOS_BUILD_NUMBER in Codemagic UI. It is not a secret.
# Explicit numbering avoids silently reusing an existing App Store build.
number="${IOS_BUILD_NUMBER:-}"
if [[ ! "$number" =~ ^[1-9][0-9]{0,3}$ ]] || (( number <= 14 )); then
  echo 'Set IOS_BUILD_NUMBER to a new integer 15..9999, higher than every previously uploaded build.' >&2
  exit 1
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $number" RentShare/Info.plist
