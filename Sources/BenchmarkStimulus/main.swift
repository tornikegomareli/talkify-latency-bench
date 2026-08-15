import AppKit
import Foundation

private enum DriverError: LocalizedError {
  case invalidArguments
  case missingAudioFile(String)
  case missingClickDriver
  case armTimedOut
  case clickDriverFailed(Int32)
  case playbackFailed(Int32)
  case outputUnmuteFailed(Int32)
  case spokenlyDeeplinkFailed(String)

  var errorDescription: String? {
    switch self {
    case .invalidArguments:
      "Usage: BenchmarkStimulus <audio-file> [fn|left-option|option-space|superwhisper-menu|spokenly-deeplink] [--arm]"
    case .missingAudioFile(let path):
      "Audio file does not exist: \(path)"
    case .missingClickDriver:
      "Install cliclick with: brew install cliclick"
    case .armTimedOut:
      "Latency Bench did not acknowledge the arm request within two seconds."
    case .clickDriverFailed(let status):
      "cliclick failed with exit status \(status)."
    case .playbackFailed(let status):
      "Audio playback failed with exit status \(status)."
    case .outputUnmuteFailed(let status):
      "Could not unmute benchmark audio; osascript exited with status \(status)."
    case .spokenlyDeeplinkFailed(let action):
      "Could not open spokenly://\(action)."
    }
  }
}

private enum DriverMode: String {
  case function = "fn"
  case leftOption = "left-option"
  case optionSpace = "option-space"
  case superwhisperMenu = "superwhisper-menu"
  case spokenlyDeeplink = "spokenly-deeplink"

  var notificationValue: String {
    switch self {
    case .function:
      "Fn"
    case .leftOption:
      "Left ⌥"
    case .optionSpace:
      "⌥ Space"
    case .superwhisperMenu:
      "superwhisper menu"
    case .spokenlyDeeplink:
      "Spokenly deeplink"
    }
  }
}

private final class ShortcutDriver {
  private let clickDriverURL: URL?
  private var heldModifiers: [String] = []

  init(clickDriverURL: URL?) {
    self.clickDriverURL = clickDriverURL
  }

  func start(_ mode: DriverMode) throws -> UInt64 {
    switch mode {
    case .function:
      let instant = try runClickDriver(["kd:fn"])
      heldModifiers = ["fn"]
      return instant
    case .leftOption:
      let instant = try runClickDriver(["kd:alt"])
      heldModifiers = ["alt"]
      return instant
    case .optionSpace:
      return try runClickDriver(["kd:alt", "kp:space", "ku:alt"])
    case .superwhisperMenu:
      return try runSuperwhisperMenuAction()
    case .spokenlyDeeplink:
      return try runSpokenlyDeeplink("start")
    }
  }

  func stop(_ mode: DriverMode) throws -> UInt64 {
    switch mode {
    case .function:
      let instant = try runClickDriver(["ku:fn"])
      heldModifiers = []
      return instant
    case .leftOption:
      let instant = try runClickDriver(["ku:alt"])
      heldModifiers = []
      return instant
    case .optionSpace:
      return try runClickDriver(["kd:alt", "kp:space", "ku:alt"])
    case .superwhisperMenu:
      return try runSuperwhisperMenuAction()
    case .spokenlyDeeplink:
      return try runSpokenlyDeeplink("stop")
    }
  }

  deinit {
    for modifier in heldModifiers {
      _ = try? runClickDriver(["ku:\(modifier)"])
    }
  }

  private func runClickDriver(_ commands: [String]) throws -> UInt64 {
    guard let clickDriverURL else {
      throw DriverError.missingClickDriver
    }
    let process = Process()
    process.executableURL = clickDriverURL
    process.arguments = commands
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.standardError
    let started = DispatchTime.now().uptimeNanoseconds
    try process.run()
    process.waitUntilExit()
    let finished = DispatchTime.now().uptimeNanoseconds
    guard process.terminationStatus == 0 else {
      throw DriverError.clickDriverFailed(process.terminationStatus)
    }
    return started + ((finished - started) / 2)
  }

  private func runSuperwhisperMenuAction() throws -> UInt64 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = [
      "-e",
      "tell application \"System Events\" to tell process \"superwhisper\" to click menu item \"Toggle Recording\" of menu 1 of menu bar item \"superwhisper\" of menu bar 1"
    ]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.standardError
    let started = DispatchTime.now().uptimeNanoseconds
    try process.run()
    process.waitUntilExit()
    let finished = DispatchTime.now().uptimeNanoseconds
    guard process.terminationStatus == 0 else {
      throw DriverError.clickDriverFailed(process.terminationStatus)
    }
    return started + ((finished - started) / 2)
  }

  private func runSpokenlyDeeplink(_ action: String) throws -> UInt64 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-g", "spokenly://\(action)"]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.standardError
    let started = DispatchTime.now().uptimeNanoseconds
    try process.run()
    process.waitUntilExit()
    let finished = DispatchTime.now().uptimeNanoseconds
    guard process.terminationStatus == 0 else {
      throw DriverError.spokenlyDeeplinkFailed(action)
    }
    return started + ((finished - started) / 2)
  }
}

private let notificationName = Notification.Name("com.talkify.latency-bench.trigger")
private let commandNotificationName = Notification.Name(
  "com.talkify.latency-bench.command"
)
private let commandAcknowledgementName = Notification.Name(
  "com.talkify.latency-bench.command-acknowledgement"
)

private final class ArmAcknowledgementObserver: NSObject {
  let requestID: String
  private(set) var received = false

  init(requestID: String) {
    self.requestID = requestID
  }

  @objc func capture(_ notification: Notification) {
    guard notification.userInfo?["requestID"] as? String == requestID else { return }
    received = true
  }
}

private func requestArm() throws {
  let center = DistributedNotificationCenter.default()
  let requestID = UUID().uuidString
  let observer = ArmAcknowledgementObserver(requestID: requestID)
  center.addObserver(
    observer,
    selector: #selector(ArmAcknowledgementObserver.capture(_:)),
    name: commandAcknowledgementName,
    object: "LatencyBench"
  )
  defer { center.removeObserver(observer) }

  center.postNotificationName(
    commandNotificationName,
    object: "BenchmarkStimulus",
    userInfo: ["command": "arm", "requestID": requestID],
    deliverImmediately: true
  )

  let deadline = Date().addingTimeInterval(2)
  while !observer.received, Date() < deadline {
    _ = RunLoop.current.run(
      mode: .default,
      before: min(deadline, Date().addingTimeInterval(0.05))
    )
  }
  guard observer.received else {
    throw DriverError.armTimedOut
  }
}

private func activateLatencyBench() {
  guard let app = NSRunningApplication.runningApplications(
    withBundleIdentifier: "com.talkify.latency-bench"
  ).first else { return }
  app.activate(options: [.activateAllWindows])
  Thread.sleep(forTimeInterval: 0.2)
}

private func post(
  edge: String,
  trigger: DriverMode,
  atNanoseconds instant: UInt64
) {
  DistributedNotificationCenter.default().postNotificationName(
    notificationName,
    object: "BenchmarkStimulus",
    userInfo: [
      "trigger": trigger.notificationValue,
      "edge": edge,
      "uptimeNanoseconds": NSNumber(value: instant)
    ],
    deliverImmediately: true
  )
}

private func play(_ audioURL: URL) throws {
  let player = Process()
  player.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
  player.arguments = [audioURL.path]
  try player.run()
  player.waitUntilExit()
  guard player.terminationStatus == 0 else {
    throw DriverError.playbackFailed(player.terminationStatus)
  }
}

private func unmuteOutput() throws {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
  process.arguments = ["-e", "set volume without output muted"]
  process.standardOutput = FileHandle.nullDevice
  process.standardError = FileHandle.standardError
  try process.run()
  process.waitUntilExit()
  guard process.terminationStatus == 0 else {
    throw DriverError.outputUnmuteFailed(process.terminationStatus)
  }
}

private func clickDriverURL() -> URL? {
  let paths = [
    "/opt/homebrew/bin/cliclick",
    "/usr/local/bin/cliclick"
  ]
  return paths
    .first { FileManager.default.isExecutableFile(atPath: $0) }
    .map(URL.init(fileURLWithPath:))
}

do {
  guard (2...4).contains(CommandLine.arguments.count) else {
    throw DriverError.invalidArguments
  }
  let mode: DriverMode
  if CommandLine.arguments.count >= 3, CommandLine.arguments[2] != "--arm" {
    guard let parsedMode = DriverMode(rawValue: CommandLine.arguments[2]) else {
      throw DriverError.invalidArguments
    }
    mode = parsedMode
  } else {
    mode = .function
  }
  let shouldArm = CommandLine.arguments.dropFirst(2).contains("--arm")
  let audioPath = NSString(string: CommandLine.arguments[1]).expandingTildeInPath
  guard FileManager.default.fileExists(atPath: audioPath) else {
    throw DriverError.missingAudioFile(audioPath)
  }
  let shortcutDriver = ShortcutDriver(clickDriverURL: clickDriverURL())
  if shouldArm {
    activateLatencyBench()
    try requestArm()
  }
  let pressInstant = try shortcutDriver.start(mode)
  post(edge: "pressed", trigger: mode, atNanoseconds: pressInstant)
  if mode == .leftOption {
    Thread.sleep(forTimeInterval: 0.2)
    try unmuteOutput()
    Thread.sleep(forTimeInterval: 0.3)
  } else {
    Thread.sleep(forTimeInterval: 0.5)
  }
  try play(URL(fileURLWithPath: audioPath))
  Thread.sleep(forTimeInterval: 0.3)
  let releaseInstant = try shortcutDriver.stop(mode)
  post(edge: "released", trigger: mode, atNanoseconds: releaseInstant)
} catch {
  FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
  exit(EXIT_FAILURE)
}
