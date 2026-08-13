#!/bin/zsh

set -euo pipefail

tool_directory="${0:A:h}"
output_directory="$tool_directory/dist"
app_directory="$output_directory/LatencyBench.app"

swift build --package-path "$tool_directory" -c release

rm -rf "$app_directory"
mkdir -p "$app_directory/Contents/MacOS"
mkdir -p "$app_directory/Contents/Resources"
install -m 755 \
  "$tool_directory/.build/arm64-apple-macosx/release/LatencyBench" \
  "$app_directory/Contents/MacOS/LatencyBench"
install -m 755 \
  "$tool_directory/.build/arm64-apple-macosx/release/BenchmarkStimulus" \
  "$app_directory/Contents/MacOS/BenchmarkStimulus"
install -m 644 \
  "$tool_directory/Resources/Info.plist" \
  "$app_directory/Contents/Info.plist"
"$tool_directory/prepare-stimulus.sh" >/dev/null
install -m 644 \
  "$output_directory/stimulus-neutral.aiff" \
  "$app_directory/Contents/Resources/stimulus-neutral.aiff"

codesign --force --deep --sign - "$app_directory"
print "$app_directory"
