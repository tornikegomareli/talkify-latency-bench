#!/bin/zsh

set -euo pipefail

tool_directory="${0:A:h}"
trial_count="${1:-}"
trigger="${2:-fn}"
results_file="$HOME/Library/Application Support/TalkifyLatencyBench/results.json"

if [[ ! "$trial_count" =~ '^[1-9][0-9]*$' ]]; then
  print -u2 "Usage: ./run-batch.sh <trial-count> [fn|left-option|option-space|superwhisper-menu]"
  exit 2
fi

result_count() {
  if [[ -f "$results_file" ]]; then
    /usr/bin/jq 'length' "$results_file"
  else
    print 0
  fi
}

for trial in {1..$trial_count}; do
  before="$(result_count)"
  "$tool_directory/run-stimulus.sh" "$trigger"

  for _ in {1..80}; do
    after="$(result_count)"
    if (( after > before )); then
      print "Completed batch trial $trial of $trial_count"
      break
    fi
    sleep 0.25
  done

  if (( $(result_count) <= before )); then
    print -u2 "Trial $trial did not produce a saved result within 20 seconds."
    exit 1
  fi
  sleep 2
done
