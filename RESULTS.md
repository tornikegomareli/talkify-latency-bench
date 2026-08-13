# Results

Measured 13 August 2026 on one MacBook Pro (M4 Max, macOS 26). Every engine ran the same phrase through the same harness, editor and clock: **"Fast speech to text should feel instant."**

Twenty measured trials per engine, after one discarded warmup. The metric is the **recording-end action to final visible text** — key release for push-to-talk, the stop shortcut for toggles.

## Latency

| Engine | Mode | Median | P95 | Min | Max | vs Talkify |
|---|---|---:|---:|---:|---:|---:|
| **Talkify** (development) | Apple SpeechAnalyzer | **123 ms** | 140 ms | 108 ms | 141 ms | — |
| superwhisper 2.16.1 | Standard EN local | 216 ms | 247 ms | 187 ms | 254 ms | 1.8× |
| VoiceInk 2.11 | Parakeet V3 local | 324 ms | 351 ms | 308 ms | 375 ms | 2.6× |
| Wispr Flow 1.6.492 | Default (cloud) | 587 ms | 693 ms | 522 ms | 792 ms | 4.8× |
| MacWhisper 14.7 | Large v3 Turbo local | 1149 ms | 1226 ms | 1110 ms | 1253 ms | 9.4× |

Talkify's slowest trial (141 ms) is still faster than every other engine's fastest.

## Accuracy

Median word error rate was **0.000 for all five engines**, and the median trial was a perfect transcript everywhere. Consistency differed:

| Engine | Trials below a perfect transcript | Worst transcript observed |
|---|---:|---|
| Talkify | **8 / 20** | "Well, that speech to test me feel instant." |
| superwhisper | 1 / 20 | "Ask speech to text should feel instant" |
| VoiceInk | 0 / 20 | — perfect on every trial |
| Wispr Flow | 1 / 20 | "That speech-to-text should be instant." |
| MacWhisper | 3 / 20 | "Delta Force. Delta Force." |

**Talkify is the fastest engine here and the least consistent one.** Both come from the same decision: it finalizes soonest, so it commits with the least trailing audio to lean on. Version 1 also inserts raw recognized text with no cleanup pass. If you need the transcript right the first time more than you need it now, VoiceInk was flawless in this run.

## What this measures, and what it does not

The stimulus plays through the Mac's speaker and is picked up by its microphone, so the number is a **whole-loop measurement on one machine**, not a model benchmark. Inside every figure: playback, the acoustic path, echo cancellation, recognition, and the app's own text insertion.

- It is repeatable on one Mac, and reflects what a user actually waits for.
- It is **not** a like-for-like comparison of recognition models.
- Wispr Flow is cloud-based, so its result depends on the network at the time of measurement.
- Each engine used the trigger it supports best (Fn push-to-talk where available, otherwise its own toggle). superwhisper ignored synthetic key events, so its menu control was used instead — recorded in the data as the trigger.
- Every other speech-to-text app was quit while an engine was under test.

## Reproducing it

```sh
./build-app.sh && open dist/LatencyBench.app
./run-batch.sh 20 fn          # after one discarded warmup
./export-measured-results.sh  # exports only the ranges in measured-runs.json
```

`measured-runs.json` pins the exact trial range used for each engine, and the exporter refuses to run if a range is incomplete or two ranges overlap — warmups and video takes cannot leak into the dataset.

Raw per-trial data, including every transcript: [`output/results/measured-results.csv`](output/results/measured-results.csv) and [`measured-results.json`](output/results/measured-results.json).

## Videos

`output/comparisons/` holds side-by-side recordings of the trial nearest each engine's median, in 1920×1080 and 1080×1920. The labels show the 20-run medians, not the take's own timing.
