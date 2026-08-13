# Talkify Latency Bench

How long does dictation make you wait? This measures the time from the
recording-end action to visible text, using the same editor and the same clock
for every speech-to-text app.

**[Results](RESULTS.md): Talkify 123 ms · superwhisper 216 ms · VoiceInk 324 ms ·
Wispr Flow 587 ms · MacWhisper 1149 ms** (median of 20 trials each). Read the
results for the accuracy trade-off and what the number does and does not cover.

Built for [Talkify](https://github.com/tornikegomareli/Talkify), but the harness
is engine-agnostic: add any app that types into the frontmost field.

## Build

```sh
./build-app.sh
open dist/LatencyBench.app
```

Select the engine, model, and trigger. Use Fn push-to-talk where the app supports it. Use the app's stop toggle when it does not. Arm the trial before each run.

Click **Run fixed input**. The app starts recording, plays `Fast speech to text should feel instant.`, waits 300 ms, then ends recording. Keep the MacBook Pro microphone and speaker volume unchanged across all runs.

The driver uses `cliclick` to hold Fn. Install it with `brew install cliclick` when it is not present.

The in-app button needs Accessibility access. Without it, run the driver from an authorized terminal. It arms the app before starting:

```sh
./run-stimulus.sh
./run-stimulus.sh left-option
./run-stimulus.sh option-space
./run-stimulus.sh superwhisper-menu
```

Use `superwhisper-menu` when superwhisper ignores synthetic keyboard events. The recorded trigger identifies this method in exported data.

Run a measured batch after one discarded warmup:

```sh
./run-batch.sh 20 fn
./run-batch.sh 20 left-option
./run-batch.sh 20 option-space
./run-batch.sh 20 superwhisper-menu
```

Record the measured trial range in `measured-runs.json`. Then export only those
trials:

```sh
./export-measured-results.sh
```

The exporter fails if a range is incomplete or if two run selectors overlap.
This keeps warmups and representative video takes out of the measured dataset.

## Protocol

1. Quit every speech-to-text app except the engine under test.
2. Warm the engine and model with one discarded run.
3. Run 20 measured trials with the short phrase.
4. Compare median latency, P95 latency, and median accuracy.
5. Record the trial nearest each engine's median.

The primary metric is recording-end action to final visible text. For push-to-talk, that action is key release. For toggle shortcuts, it is the stop shortcut. First visible text is secondary. A 350 ms quiet window confirms that text stopped changing, but it is excluded from the latency.

The acoustic speaker-to-microphone path is repeatable on one Mac. It is not a model-only benchmark. Network, echo cancellation, and app insertion time remain part of the result.

The validated VoiceInk setup uses its Option-Space toggle with
`./run-batch.sh 20 option-space`. The batch waits two seconds after each trial
before it starts the next recording.

## Data

Results stay on this Mac:

```text
~/Library/Application Support/TalkifyLatencyBench/results.json
~/Library/Application Support/TalkifyLatencyBench/results.csv
```

Measured exports are written to `output/results/`.

Talkify DEBUG builds also write stage timings without transcript text or audio:

```text
~/Library/Application Support/Talkify/Debug/dictation-latency.jsonl
```

## Video export

Record each representative trial separately. Align each source at its visible
recording-end transition. Keep the same short pre-roll on both sides, then
export both layouts:

```sh
./compose-comparison.sh talkify.mov competitor.mov "Wispr Flow" 8.66 8.22 4 output/talkify-vs-flow 123 587
```

The latency labels should use the measured 20-run medians, not the result from
the representative video take. The command writes a 1920×1080 landscape video
and a 1080×1920 vertical video.
