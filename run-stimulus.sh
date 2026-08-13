#!/bin/zsh

set -euo pipefail

tool_directory="${0:A:h}"
app_directory="$tool_directory/dist/LatencyBench.app"
driver="$app_directory/Contents/MacOS/BenchmarkStimulus"
audio_file="$app_directory/Contents/Resources/stimulus-neutral.aiff"
trigger="${1:-fn}"

if [[ ! -x "$driver" || ! -f "$audio_file" ]]; then
  "$tool_directory/build-app.sh" >/dev/null
fi

exec "$driver" "$audio_file" "$trigger" --arm
