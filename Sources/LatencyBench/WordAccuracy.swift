import Foundation

enum WordAccuracy {
  struct Score: Equatable, Sendable {
    let wordErrorRate: Double
    let accuracy: Double
  }

  static func compare(expected: String, actual: String) -> Score {
    let expectedWords = words(in: expected)
    let actualWords = words(in: actual)

    guard !expectedWords.isEmpty else {
      let rate = actualWords.isEmpty ? 0.0 : 1.0
      return Score(wordErrorRate: rate, accuracy: 1 - rate)
    }

    var previous = Array(0...actualWords.count)
    for (expectedIndex, expectedWord) in expectedWords.enumerated() {
      var current = Array(repeating: 0, count: actualWords.count + 1)
      current[0] = expectedIndex + 1
      for (actualIndex, actualWord) in actualWords.enumerated() {
        let substitution = previous[actualIndex] + (expectedWord == actualWord ? 0 : 1)
        let deletion = previous[actualIndex + 1] + 1
        let insertion = current[actualIndex] + 1
        current[actualIndex + 1] = min(substitution, deletion, insertion)
      }
      previous = current
    }

    let errorRate = Double(previous[actualWords.count]) / Double(expectedWords.count)
    return Score(
      wordErrorRate: errorRate,
      accuracy: max(0, 1 - errorRate)
    )
  }

  private static func words(in text: String) -> [String] {
    text.lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
  }
}
