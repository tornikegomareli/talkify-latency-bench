import Testing
@testable import LatencyBench

struct WordAccuracyTests {
  @Test("Equivalent punctuation and case have zero word error rate")
  func normalizesPunctuationAndCase() {
    let score = WordAccuracy.compare(
      expected: "Hello, Talkify!",
      actual: "hello talkify"
    )

    #expect(score.wordErrorRate == 0)
    #expect(score.accuracy == 1)
  }

  @Test("A replacement counts as one word error")
  func countsReplacement() {
    let score = WordAccuracy.compare(
      expected: "speech becomes useful text",
      actual: "speech becomes clean text"
    )

    #expect(score.wordErrorRate == 0.25)
    #expect(score.accuracy == 0.75)
  }

  @Test("An empty result has full error for nonempty expected text")
  func handlesEmptyResult() {
    let score = WordAccuracy.compare(expected: "one two", actual: "")

    #expect(score.wordErrorRate == 1)
    #expect(score.accuracy == 0)
  }
}
