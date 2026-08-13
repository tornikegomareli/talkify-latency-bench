import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class LatencyBenchController {
  var engine = "Talkify" {
    didSet { engineVersion = Self.installedVersion(for: engine) }
  }
  var engineVersion = "development"
  var mode = "Default"
  var trigger = BenchmarkTrigger.function
  var selectedPhraseID = BenchmarkPhrases.all[0].id
  var results: [BenchmarkResult] = []
  var focusRequestID = 0
  var errorMessage: String?
  var isStimulusRunning = false

  private(set) var machine = LatencyTrialMachine()

  @ObservationIgnored private let resultStore = BenchmarkResultStore()
  @ObservationIgnored private let eventMonitor = TriggerEventMonitor()
  @ObservationIgnored private var completionTask: Task<Void, Never>?
  @ObservationIgnored private var stimulusTask: Task<Void, Never>?

  let engines = ["Talkify", "Wispr Flow", "superwhisper", "MacWhisper", "VoiceInk"]

  init() {
    do {
      results = try resultStore.load()
    } catch {
      errorMessage = "Could not load earlier results: \(error.localizedDescription)"
    }
  }

  var selectedPhrase: BenchmarkPhrase {
    BenchmarkPhrases.all.first { $0.id == selectedPhraseID } ?? BenchmarkPhrases.all[0]
  }

  var summaries: [BenchmarkSummary] {
    BenchmarkSummary.make(from: results)
      .filter { $0.phraseID == selectedPhraseID }
  }

  var currentResult: BenchmarkResult? { machine.state.result }

  var statusText: String {
    switch machine.state.phase {
    case .idle:
      "Choose an engine and arm a trial"
    case .armed:
      "Ready for \(trigger.rawValue)"
    case .recording:
      "Recording"
    case .released:
      "Stopped, waiting for text"
    case .settling:
      "Text detected"
    case .completed:
      "Trial saved"
    }
  }

  func startMonitoring() {
    eventMonitor.start(
      handler: { [weak self] event in
        self?.receive(event)
      },
      armHandler: { [weak self] in
        self?.armTrial()
      }
    )
  }

  func stopMonitoring() {
    eventMonitor.stop()
    completionTask?.cancel()
    stimulusTask?.cancel()
  }

  func armTrial() {
    completionTask?.cancel()
    let phrase = selectedPhrase
    let matchingResults = results.filter {
      $0.engine == engine && $0.mode == mode && $0.phraseID == phrase.id
    }
    let configuration = TrialConfiguration(
      id: UUID(),
      createdAt: .now,
      engine: engine,
      engineVersion: engineVersion,
      mode: mode,
      trigger: trigger.rawValue,
      phraseID: phrase.id,
      expectedText: phrase.text,
      trialNumber: matchingResults.count + 1
    )
    run(machine.reduce(.arm(configuration)))
  }

  func runFixedStimulus() {
    guard trigger.driverArgument != nil else {
      errorMessage = "The fixed input does not support \(trigger.rawValue)."
      return
    }
    guard let audioURL = Bundle.main.url(
      forResource: "stimulus-neutral",
      withExtension: "aiff"
    ) else {
      errorMessage = "The fixed input audio is missing. Rebuild Latency Bench."
      return
    }

    let trigger = trigger
    armTrial()
    isStimulusRunning = true
    stimulusTask?.cancel()
    stimulusTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(300))
        try await StimulusRunner.run(audioURL: audioURL, trigger: trigger)
        self?.errorMessage = nil
      } catch is CancellationError {
      } catch {
        self?.errorMessage = error.localizedDescription
      }
      self?.isStimulusRunning = false
    }
  }

  func editorChanged(_ text: String, atNanoseconds instant: UInt64) {
    run(machine.reduce(.textChanged(text, atNanoseconds: instant)))
  }

  func liveMilliseconds(atNanoseconds instant: UInt64) -> Double {
    if let result = machine.state.result {
      return result.releaseToFinalTextMilliseconds
    }
    guard let released = machine.state.releasedNanoseconds, instant > released else { return 0 }
    return Double(instant - released) / 1_000_000
  }

  func openResultsFolder() {
    do {
      try FileManager.default.createDirectory(
        at: resultStore.directoryURL,
        withIntermediateDirectories: true
      )
      NSWorkspace.shared.open(resultStore.directoryURL)
    } catch {
      errorMessage = "Could not open the results folder: \(error.localizedDescription)"
    }
  }

  private func receive(_ event: TriggerEventMonitor.Event) {
    guard event.trigger == trigger else { return }
    switch event.edge {
    case .pressed:
      run(machine.reduce(.triggerPressed(atNanoseconds: event.uptimeNanoseconds)))
    case .released:
      run(machine.reduce(.triggerReleased(atNanoseconds: event.uptimeNanoseconds)))
    }
  }

  private func run(_ effects: [LatencyTrialEffect]) {
    for effect in effects {
      switch effect {
      case .clearAndFocusEditor:
        focusRequestID += 1

      case .scheduleCompletion(let revision):
        completionTask?.cancel()
        completionTask = Task { [weak self] in
          try? await Task.sleep(for: .milliseconds(350))
          guard !Task.isCancelled else { return }
          self?.run(self?.machine.reduce(.quietWindowElapsed(revision: revision)) ?? [])
        }

      case .save(let result):
        results.append(result)
        do {
          try resultStore.save(results)
          errorMessage = nil
        } catch {
          errorMessage = "Could not save this trial: \(error.localizedDescription)"
        }
      }
    }
  }

  private static func installedVersion(for engine: String) -> String {
    let paths = [
      "Wispr Flow": "/Applications/Wispr Flow.app",
      "superwhisper": "/Applications/superwhisper.app",
      "MacWhisper": "/Applications/MacWhisper.app",
      "VoiceInk": "/Applications/VoiceInk.app"
    ]
    guard let path = paths[engine],
          let bundle = Bundle(path: path),
          let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
      return engine == "Talkify" ? "development" : "unknown"
    }
    return version
  }
}
