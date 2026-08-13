import Foundation
import Testing
@testable import LatencyBench

struct LatencyTrialMachineTests {
  @Test("A post-release mutation records first and final visible latency")
  func recordsPostReleaseLatency() throws {
    var machine = LatencyTrialMachine()
    let configuration = trialConfiguration()

    #expect(machine.reduce(.arm(configuration)) == [.clearAndFocusEditor])
    #expect(machine.reduce(.triggerReleased(atNanoseconds: 1_000_000_000)) == [])
    #expect(
      machine.reduce(
        .textChanged("Talkify turns speech into text.", atNanoseconds: 1_240_000_000)
      ) == [.scheduleCompletion(revision: 1)]
    )

    let effects = machine.reduce(.quietWindowElapsed(revision: 1))
    let result = try #require(effects.savedResult)

    #expect(result.releaseToFirstTextMilliseconds == 240)
    #expect(result.releaseToFinalTextMilliseconds == 240)
    #expect(result.textWasVisibleAtRelease == false)
    #expect(result.wordErrorRate == 0)
    #expect(machine.state.phase == .completed)
  }

  @Test("Streaming text visible before release reports zero release latency")
  func recordsTextVisibleBeforeRelease() throws {
    var machine = LatencyTrialMachine()
    _ = machine.reduce(.arm(trialConfiguration()))
    #expect(
      machine.reduce(
        .textChanged("Talkify turns speech into text.", atNanoseconds: 900_000_000)
      ) == []
    )
    #expect(
      machine.reduce(.triggerReleased(atNanoseconds: 1_000_000_000))
        == [.scheduleCompletion(revision: 1)]
    )

    let result = try #require(
      machine.reduce(.quietWindowElapsed(revision: 1)).savedResult
    )

    #expect(result.releaseToFirstTextMilliseconds == 0)
    #expect(result.releaseToFinalTextMilliseconds == 0)
    #expect(result.textWasVisibleAtRelease)
  }

  @Test("A stale quiet-window callback cannot finish a newer mutation")
  func ignoresStaleCompletion() {
    var machine = LatencyTrialMachine()
    _ = machine.reduce(.arm(trialConfiguration()))
    _ = machine.reduce(.triggerReleased(atNanoseconds: 1_000_000_000))
    _ = machine.reduce(.textChanged("Talkify", atNanoseconds: 1_100_000_000))
    _ = machine.reduce(
      .textChanged("Talkify turns speech into text.", atNanoseconds: 1_220_000_000)
    )

    #expect(machine.reduce(.quietWindowElapsed(revision: 1)) == [])
    #expect(machine.state.phase == .settling)
    #expect(
      machine.reduce(.quietWindowElapsed(revision: 2)).savedResult?
        .releaseToFinalTextMilliseconds == 220
    )
  }

  @Test("Empty editor changes do not count as inserted text")
  func ignoresEmptyText() {
    var machine = LatencyTrialMachine()
    _ = machine.reduce(.arm(trialConfiguration()))
    _ = machine.reduce(.triggerReleased(atNanoseconds: 1_000_000_000))

    #expect(machine.reduce(.textChanged("   ", atNanoseconds: 1_050_000_000)) == [])
    #expect(machine.state.phase == .released)
    #expect(machine.state.firstMutationNanoseconds == nil)
  }

  private func trialConfiguration() -> TrialConfiguration {
    TrialConfiguration(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      engine: "Talkify",
      engineVersion: "1.0",
      mode: "Default",
      trigger: "F13",
      phraseID: "short-01",
      expectedText: "Talkify turns speech into text.",
      trialNumber: 1
    )
  }
}

private extension [LatencyTrialEffect] {
  var savedResult: BenchmarkResult? {
    compactMap { effect -> BenchmarkResult? in
      guard case .save(let result) = effect else { return nil }
      return result
    }.first
  }
}
