import Foundation

struct LatencyTrialMachine: Sendable {
  enum Phase: String, Equatable, Sendable {
    case idle
    case armed
    case recording
    case released
    case settling
    case completed
  }

  struct State: Equatable, Sendable {
    var phase: Phase = .idle
    var configuration: TrialConfiguration?
    var pressedNanoseconds: UInt64?
    var releasedNanoseconds: UInt64?
    var firstMutationNanoseconds: UInt64?
    var lastMutationNanoseconds: UInt64?
    var actualText = ""
    var textWasVisibleAtRelease = false
    var revision = 0
    var result: BenchmarkResult?
  }

  enum Action: Equatable, Sendable {
    case arm(TrialConfiguration)
    case triggerPressed(atNanoseconds: UInt64)
    case triggerReleased(atNanoseconds: UInt64)
    case textChanged(String, atNanoseconds: UInt64)
    case quietWindowElapsed(revision: Int)
    case reset
  }

  var state = State()

  mutating func reduce(_ action: Action) -> [LatencyTrialEffect] {
    switch action {
    case .arm(let configuration):
      state = State(phase: .armed, configuration: configuration)
      return [.clearAndFocusEditor]

    case .triggerPressed(let instant):
      guard state.phase == .armed else { return [] }
      state.phase = .recording
      state.pressedNanoseconds = instant
      return []

    case .triggerReleased(let instant):
      guard state.phase == .armed || state.phase == .recording else { return [] }
      state.releasedNanoseconds = instant
      state.textWasVisibleAtRelease = !state.actualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      if state.textWasVisibleAtRelease {
        state.phase = .settling
        return [.scheduleCompletion(revision: state.revision)]
      }
      state.phase = .released
      return []

    case .textChanged(let text, let instant):
      guard state.configuration != nil else { return [] }
      state.actualText = text
      guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
      state.firstMutationNanoseconds = state.firstMutationNanoseconds ?? instant
      state.lastMutationNanoseconds = instant
      state.revision += 1
      guard state.releasedNanoseconds != nil else { return [] }
      state.phase = .settling
      return [.scheduleCompletion(revision: state.revision)]

    case .quietWindowElapsed(let revision):
      guard revision == state.revision,
            state.phase == .settling,
            let configuration = state.configuration,
            let release = state.releasedNanoseconds,
            let firstMutation = state.firstMutationNanoseconds,
            let lastMutation = state.lastMutationNanoseconds else {
        return []
      }

      let accuracy = WordAccuracy.compare(
        expected: configuration.expectedText,
        actual: state.actualText
      )
      let result = BenchmarkResult(
        id: configuration.id,
        createdAt: configuration.createdAt,
        engine: configuration.engine,
        engineVersion: configuration.engineVersion,
        mode: configuration.mode,
        trigger: configuration.trigger,
        phraseID: configuration.phraseID,
        expectedText: configuration.expectedText,
        actualText: state.actualText,
        trialNumber: configuration.trialNumber,
        releaseToFirstTextMilliseconds: milliseconds(from: release, to: firstMutation),
        releaseToFinalTextMilliseconds: milliseconds(from: release, to: lastMutation),
        textWasVisibleAtRelease: state.textWasVisibleAtRelease,
        wordErrorRate: accuracy.wordErrorRate,
        accuracy: accuracy.accuracy
      )
      state.phase = .completed
      state.result = result
      return [.save(result)]

    case .reset:
      state = State()
      return []
    }
  }

  private func milliseconds(from start: UInt64, to end: UInt64) -> Double {
    guard end > start else { return 0 }
    return Double(end - start) / 1_000_000
  }
}

enum LatencyTrialEffect: Equatable, Sendable {
  case clearAndFocusEditor
  case scheduleCompletion(revision: Int)
  case save(BenchmarkResult)
}
