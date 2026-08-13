import ApplicationServices
import Foundation

enum StimulusRunnerError: LocalizedError {
  case accessibilityPermissionRequired
  case missingDriver
  case driverFailed(String)

  var errorDescription: String? {
    switch self {
    case .accessibilityPermissionRequired:
      "Allow Talkify Latency Bench in System Settings → Privacy & Security → Accessibility, or run ./run-stimulus.sh from an authorized terminal."
    case .missingDriver:
      "The fixed-input driver is missing. Rebuild Latency Bench."
    case .driverFailed(let message):
      message
    }
  }
}

enum StimulusRunner {
  static func run(audioURL: URL, trigger: BenchmarkTrigger) async throws {
    guard AXIsProcessTrusted() else {
      throw StimulusRunnerError.accessibilityPermissionRequired
    }
    guard let driverArgument = trigger.driverArgument else {
      throw StimulusRunnerError.driverFailed(
        "The fixed-input driver does not support \(trigger.rawValue)."
      )
    }
    guard let driverURL = Bundle.main.executableURL?
      .deletingLastPathComponent()
      .appendingPathComponent("BenchmarkStimulus"),
      FileManager.default.isExecutableFile(atPath: driverURL.path) else {
      throw StimulusRunnerError.missingDriver
    }

    try await Task.detached {
      let process = Process()
      let errorPipe = Pipe()
      process.executableURL = driverURL
      process.arguments = [audioURL.path, driverArgument]
      process.standardError = errorPipe
      try process.run()
      process.waitUntilExit()
      guard process.terminationStatus == 0 else {
        let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: data, encoding: .utf8)?
          .trimmingCharacters(in: .whitespacesAndNewlines)
        throw StimulusRunnerError.driverFailed(
          message?.isEmpty == false ? message! : "The fixed-input driver failed."
        )
      }
    }.value
  }
}
