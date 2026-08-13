import Foundation
import Testing
@testable import LatencyBench

struct BenchmarkResultStoreTests {
  @Test("JSON and CSV exports round-trip with POSIX decimal separators")
  func writesPortableExports() throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = BenchmarkResultStore(directoryURL: directory)
    let result = benchmarkResult()

    try store.save([result])

    #expect(try store.load() == [result])
    let csv = try String(contentsOf: store.csvURL, encoding: .utf8)
    #expect(csv.contains("\"3319.017\""))
    #expect(csv.contains("\"0.1250\""))
  }

  private func benchmarkResult() -> BenchmarkResult {
    BenchmarkResult(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
      createdAt: Date(timeIntervalSince1970: 1_700_000_000),
      engine: "Talkify",
      engineVersion: "1.0",
      mode: "Default",
      trigger: "F13",
      phraseID: "short-01",
      expectedText: "hello",
      actualText: "hello",
      trialNumber: 1,
      releaseToFirstTextMilliseconds: 300.5,
      releaseToFinalTextMilliseconds: 3319.016541,
      textWasVisibleAtRelease: false,
      wordErrorRate: 0.125,
      accuracy: 0.875
    )
  }
}
