import Foundation

struct BenchmarkResultStore: Sendable {
  let directoryURL: URL

  init(directoryURL: URL? = nil) {
    if let directoryURL {
      self.directoryURL = directoryURL
      return
    }
    self.directoryURL = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    )[0].appending(path: "TalkifyLatencyBench", directoryHint: .isDirectory)
  }

  var jsonURL: URL { directoryURL.appending(path: "results.json") }
  var csvURL: URL { directoryURL.appending(path: "results.csv") }

  func load() throws -> [BenchmarkResult] {
    guard FileManager.default.fileExists(atPath: jsonURL.path) else { return [] }
    return try JSONDecoder.benchmark.decode(
      [BenchmarkResult].self,
      from: Data(contentsOf: jsonURL)
    )
  }

  func save(_ results: [BenchmarkResult]) throws {
    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )
    let json = try JSONEncoder.benchmark.encode(results)
    try json.write(to: jsonURL, options: .atomic)
    try csv(results).write(to: csvURL, atomically: true, encoding: .utf8)
  }

  private func csv(_ results: [BenchmarkResult]) -> String {
    let header = [
      "id", "created_at", "engine", "engine_version", "mode", "trigger",
      "phrase_id", "trial", "first_text_ms", "final_text_ms",
      "visible_at_release", "word_error_rate", "accuracy", "expected", "actual"
    ].joined(separator: ",")
    let rows = results.map { result in
      [
        result.id.uuidString,
        ISO8601DateFormatter().string(from: result.createdAt),
        result.engine,
        result.engineVersion,
        result.mode,
        result.trigger,
        result.phraseID,
        String(result.trialNumber),
        formatNumber(result.releaseToFirstTextMilliseconds, decimals: 3),
        formatNumber(result.releaseToFinalTextMilliseconds, decimals: 3),
        String(result.textWasVisibleAtRelease),
        formatNumber(result.wordErrorRate, decimals: 4),
        formatNumber(result.accuracy, decimals: 4),
        result.expectedText,
        result.actualText
      ].map(csvField).joined(separator: ",")
    }
    return ([header] + rows).joined(separator: "\n") + "\n"
  }

  private func csvField(_ value: String) -> String {
    "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
  }

  private func formatNumber(_ value: Double, decimals: Int) -> String {
    String(format: "%.*f", locale: Locale(identifier: "en_US_POSIX"), decimals, value)
  }
}

private extension JSONEncoder {
  static var benchmark: JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }
}

private extension JSONDecoder {
  static var benchmark: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
