import Foundation
import Testing
@testable import LatencyBench

struct BenchmarkSummaryTests {
  @Test("Summary reports median and nearest-rank P95")
  func calculatesPercentiles() throws {
    let results = (1...20).map { value in
      benchmarkResult(milliseconds: Double(value * 10))
    }

    let summary = try #require(BenchmarkSummary.make(from: results).first)

    #expect(summary.medianMilliseconds == 105)
    #expect(summary.p95Milliseconds == 190)
    #expect(summary.trialCount == 20)
  }

  private func benchmarkResult(milliseconds: Double) -> BenchmarkResult {
    BenchmarkResult(
      id: UUID(),
      createdAt: Date(timeIntervalSince1970: milliseconds),
      engine: "Talkify",
      engineVersion: "1.0",
      mode: "Default",
      trigger: "F13",
      phraseID: "short-01",
      expectedText: "hello",
      actualText: "hello",
      trialNumber: Int(milliseconds),
      releaseToFirstTextMilliseconds: milliseconds,
      releaseToFinalTextMilliseconds: milliseconds,
      textWasVisibleAtRelease: false,
      wordErrorRate: 0,
      accuracy: 1
    )
  }
}
