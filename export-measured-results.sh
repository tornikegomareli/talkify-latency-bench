#!/bin/zsh

set -euo pipefail

tool_directory="${0:A:h}"
manifest_file="${1:-$tool_directory/measured-runs.json}"
results_file="${2:-$HOME/Library/Application Support/TalkifyLatencyBench/results.json}"
output_directory="${3:-$tool_directory/output/results}"

for required_file in "$manifest_file" "$results_file"; do
  if [[ ! -f "$required_file" ]]; then
    print -u2 "Required file does not exist: $required_file"
    exit 1
  fi
done

mkdir -p "$output_directory"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

/usr/bin/jq -n \
  --slurpfile manifest "$manifest_file" \
  --slurpfile results "$results_file" '
  ($manifest[0]) as $manifest |
  ($results[0]) as $results |
  [
    $manifest.runs[] as $run |
    ([
      $results[] |
      select(
        .engine == $run.engine and
        .engineVersion == $run.engineVersion and
        .mode == $run.mode and
        .trigger == $run.trigger and
        .phraseID == $run.phraseID and
        .trialNumber >= $run.firstTrial and
        .trialNumber <= $run.lastTrial
      )
    ]) as $selected |
    if (($run.lastTrial - $run.firstTrial + 1) != $run.expectedTrials) then
      error("Invalid trial range for \($run.engine)")
    elif ($selected | length) != $run.expectedTrials then
      error("Expected \($run.expectedTrials) results for \($run.engine), found \($selected | length)")
    else
      $selected[]
    end
  ] as $selected |
  if (($selected | map(.id) | unique | length) != ($selected | length)) then
    error("Measured run selectors overlap")
  else
    $selected | sort_by(.engine, .trialNumber)
  end
  ' > "$temporary_directory/measured-results.json"

/usr/bin/jq -r '
  ([
    "id", "created_at", "engine", "engine_version", "mode", "trigger",
    "phrase_id", "trial", "first_text_ms", "final_text_ms",
    "visible_at_release", "word_error_rate", "accuracy", "expected", "actual"
  ] | @csv),
  (.[] | [
    .id, .createdAt, .engine, .engineVersion, .mode, .trigger,
    .phraseID, .trialNumber, .releaseToFirstTextMilliseconds,
    .releaseToFinalTextMilliseconds, .textWasVisibleAtRelease,
    .wordErrorRate, .accuracy, .expectedText, .actualText
  ] | @csv)
  ' "$temporary_directory/measured-results.json" \
  > "$temporary_directory/measured-results.csv"

/usr/bin/jq -n \
  --slurpfile manifest "$manifest_file" \
  --slurpfile results "$temporary_directory/measured-results.json" '
  def median:
    sort as $values |
    ($values | length) as $count |
    if $count == 0 then null
    elif ($count % 2) == 1 then $values[($count / 2 | floor)]
    else (($values[($count / 2) - 1] + $values[$count / 2]) / 2)
    end;
  def p95:
    sort as $values |
    $values[((length * 0.95 | ceil) - 1)];

  ($manifest[0]) as $manifest |
  ($results[0]) as $results |
  ([
    $manifest.runs[] as $run |
    ([
      $results[] |
      select(
        .engine == $run.engine and
        .engineVersion == $run.engineVersion and
        .mode == $run.mode and
        .trigger == $run.trigger and
        .phraseID == $run.phraseID
      )
    ]) as $group |
    {
      engine: $run.engine,
      version: $run.engineVersion,
      mode: $run.mode,
      trigger: $run.trigger,
      trials: ($group | length),
      minMilliseconds: ($group | map(.releaseToFinalTextMilliseconds) | min),
      medianMilliseconds: ($group | map(.releaseToFinalTextMilliseconds) | median),
      p95Milliseconds: ($group | map(.releaseToFinalTextMilliseconds) | p95),
      maxMilliseconds: ($group | map(.releaseToFinalTextMilliseconds) | max),
      medianAccuracy: ($group | map(.accuracy) | median),
      exactTrials: ($group | map(select(.accuracy == 1)) | length)
    }
  ]) as $summaries |
  ($summaries[] | select(.engine == $manifest.baselineEngine) | .medianMilliseconds) as $baseline |
  {
    baselineEngine: $manifest.baselineEngine,
    measuredTrials: ($results | length),
    runs: (
      $summaries |
      map(. + {latencyMultipleVersusBaseline: (.medianMilliseconds / $baseline)}) |
      sort_by(.medianMilliseconds)
    )
  }
  ' > "$temporary_directory/summary.json"

mv "$temporary_directory/measured-results.json" "$output_directory/measured-results.json"
mv "$temporary_directory/measured-results.csv" "$output_directory/measured-results.csv"
mv "$temporary_directory/summary.json" "$output_directory/summary.json"

print "$output_directory/measured-results.json"
print "$output_directory/measured-results.csv"
print "$output_directory/summary.json"
