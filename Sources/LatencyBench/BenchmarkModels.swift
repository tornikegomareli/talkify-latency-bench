import Foundation

enum BenchmarkTrigger: String, CaseIterable, Codable, Identifiable, Sendable {
  case function = "Fn"
  case f13 = "F13"
  case leftOption = "Left ⌥"
  case optionSpace = "⌥ Space"
  case superwhisperMenu = "superwhisper menu"
  case spokenlyDeeplink = "Spokenly deeplink"

  var id: Self { self }

  var driverArgument: String? {
    switch self {
    case .function:
      "fn"
    case .optionSpace:
      "option-space"
    case .leftOption:
      "left-option"
    case .superwhisperMenu:
      "superwhisper-menu"
    case .spokenlyDeeplink:
      "spokenly-deeplink"
    case .f13:
      nil
    }
  }
}

struct TrialConfiguration: Codable, Equatable, Sendable {
  let id: UUID
  let createdAt: Date
  let engine: String
  let engineVersion: String
  let mode: String
  let trigger: String
  let phraseID: String
  let expectedText: String
  let trialNumber: Int
}

struct BenchmarkResult: Codable, Equatable, Identifiable, Sendable {
  let id: UUID
  let createdAt: Date
  let engine: String
  let engineVersion: String
  let mode: String
  let trigger: String
  let phraseID: String
  let expectedText: String
  let actualText: String
  let trialNumber: Int
  let releaseToFirstTextMilliseconds: Double
  let releaseToFinalTextMilliseconds: Double
  let textWasVisibleAtRelease: Bool
  let wordErrorRate: Double
  let accuracy: Double
}

struct BenchmarkSummary: Equatable, Identifiable, Sendable {
  let engine: String
  let engineVersion: String
  let mode: String
  let phraseID: String
  let trialCount: Int
  let medianMilliseconds: Double
  let p95Milliseconds: Double
  let medianAccuracy: Double

  var id: String {
    [engine, engineVersion, mode, phraseID].joined(separator: "|")
  }

  static func make(from results: [BenchmarkResult]) -> [BenchmarkSummary] {
    let groups = Dictionary(grouping: results) { result in
      [result.engine, result.engineVersion, result.mode, result.phraseID]
        .joined(separator: "|")
    }

    return groups.values.map { group in
      let first = group[0]
      let latencies = group.map(\.releaseToFinalTextMilliseconds).sorted()
      let accuracies = group.map(\.accuracy).sorted()
      return BenchmarkSummary(
        engine: first.engine,
        engineVersion: first.engineVersion,
        mode: first.mode,
        phraseID: first.phraseID,
        trialCount: group.count,
        medianMilliseconds: percentile(0.5, values: latencies, interpolate: true),
        p95Milliseconds: percentile(0.95, values: latencies, interpolate: false),
        medianAccuracy: percentile(0.5, values: accuracies, interpolate: true)
      )
    }
    .sorted { lhs, rhs in
      if lhs.phraseID == rhs.phraseID {
        return lhs.medianMilliseconds < rhs.medianMilliseconds
      }
      return lhs.phraseID < rhs.phraseID
    }
  }

  private static func percentile(
    _ percentile: Double,
    values: [Double],
    interpolate: Bool
  ) -> Double {
    guard let first = values.first else { return 0 }
    guard values.count > 1 else { return first }

    if !interpolate {
      let rank = max(1, Int(ceil(percentile * Double(values.count))))
      return values[rank - 1]
    }

    let index = percentile * Double(values.count - 1)
    let lowerIndex = Int(floor(index))
    let upperIndex = Int(ceil(index))
    guard lowerIndex != upperIndex else { return values[lowerIndex] }
    let fraction = index - Double(lowerIndex)
    return values[lowerIndex] + ((values[upperIndex] - values[lowerIndex]) * fraction)
  }
}

enum BenchmarkPhrases {
  static let all = [
    BenchmarkPhrase(
      id: "neutral-01",
      title: "Neutral",
      text: "Fast speech to text should feel instant."
    ),
    BenchmarkPhrase(
      id: "names-01",
      title: "Names",
      text: "Send the Talkify benchmark to Nino and Giorgi before three thirty."
    ),
    BenchmarkPhrase(
      id: "punctuation-01",
      title: "Punctuation",
      text: "The result is ready, but accuracy still counts."
    )
  ]
}

struct BenchmarkPhrase: Identifiable, Hashable, Sendable {
  let id: String
  let title: String
  let text: String
}
