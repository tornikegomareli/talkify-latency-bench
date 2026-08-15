# Results

The first five engines were measured 13 August 2026. Spokenly was measured 15 August. Aqua Voice was measured 15–16 August on the same MacBook Pro (M4 Max, macOS 26).

Every engine ran the same phrase through the same harness, editor and clock: **"Fast speech to text should feel instant."**

Each engine had one discarded warmup. Latency summaries use 20 saved trials per engine. The metric starts at the recording-end action and stops at final visible text.

## Latency

| Engine | Mode | Median | P95 | Min | Max | vs Talkify |
|---|---|---:|---:|---:|---:|---:|
| **Talkify** (development) | Apple SpeechAnalyzer | **123 ms** | 140 ms | 108 ms | 141 ms | Baseline |
| Spokenly 2.27.16 | Parakeet TDT 0.6B V3 local | 189 ms | 209 ms | 156 ms | 215 ms | 1.5× |
| superwhisper 2.16.1 | Standard EN local | 216 ms | 247 ms | 187 ms | 254 ms | 1.8× |
| VoiceInk 2.11 | Parakeet V3 local | 324 ms | 351 ms | 308 ms | 375 ms | 2.6× |
| Wispr Flow 1.6.492 | Default (cloud) | 587 ms | 693 ms | 522 ms | 792 ms | 4.8× |
| Aqua Voice 0.18.22 | Avalon v1.1 cloud | 630 ms | 872 ms | 485 ms | 1012 ms | 5.1× |
| MacWhisper 14.7 | Large v3 Turbo local | 1149 ms | 1226 ms | 1110 ms | 1253 ms | 9.4× |

Talkify's slowest trial (141 ms) is still faster than every other engine's fastest.

Spokenly placed second. Talkify's median was 66 ms lower. Spokenly produced an exact transcript in all 20 trials; Talkify did so in 12.

## Accuracy

Median word error rate was **0.000 for all seven engines**. Every median trial matched the phrase. Consistency differed:

| Engine | Trials below a perfect transcript | Worst transcript observed |
|---|---:|---|
| Talkify | **8 / 20** | "Well, that speech to test me feel instant." |
| Spokenly | 0 / 20 | Perfect on every trial |
| superwhisper | 1 / 20 | "Ask speech to text should feel instant" |
| VoiceInk | 0 / 20 | Perfect on every trial |
| Wispr Flow | 1 / 20 | "That speech-to-text should be instant." |
| Aqua Voice | 2 / 20 | "Yeah, I think we'll see." |
| MacWhisper | 3 / 20 | "Delta Force. Delta Force." |

**Talkify is the fastest engine here and the least consistent one.** It finalizes soonest, so it has less trailing audio for recognition. Version 1 also inserts raw recognized text with no cleanup pass.

Spokenly and VoiceInk were flawless in this run. Spokenly had the better speed and accuracy balance at 189 ms.

Aqua returned no text once during 21 measured attempts. The latency table uses its 20 saved results because absent text has no final-text timestamp. The failed attempt remains reported here and in `measured-runs.json`.

## What this measures, and what it does not

The stimulus plays through the Mac's speaker and is picked up by its microphone, so the number is a **whole-loop measurement on one machine**, not a model benchmark. Inside every figure: playback, the acoustic path, echo cancellation, recognition, and the app's own text insertion.

- It is repeatable on one Mac, and reflects what a user actually waits for.
- It is **not** a like-for-like comparison of recognition models.
- Wispr Flow is cloud-based, so its result depends on the network at the time of measurement.
- Each engine used its best supported trigger. superwhisper used its menu because it ignored synthetic key events.
- Spokenly used its documented start and stop deeplinks. The harness opened them in the background to preserve the focused editor.
- Aqua used Fn. The driver unmuted the fixed stimulus after activation because Aqua mutes background audio while recording.
- The raw data records the trigger for every trial.
- Every other speech-to-text app was quit while an engine was under test.

## Reproducing it

```sh
./build-app.sh && open dist/LatencyBench.app
./run-batch.sh 20 fn          # after one discarded warmup
./run-batch.sh 20 spokenly-deeplink
./export-measured-results.sh  # exports only the ranges in measured-runs.json
```

`measured-runs.json` pins each measured range. The exporter rejects incomplete or overlapping ranges, which excludes warmups and video takes.

Raw per-trial data, including every transcript: [`output/results/measured-results.csv`](output/results/measured-results.csv) and [`measured-results.json`](output/results/measured-results.json).

## Videos

`output/comparisons/` holds side-by-side recordings of the trial nearest each engine's median, in 1920×1080 and 1080×1920. The labels show the 20-run medians, not the take's own timing.
