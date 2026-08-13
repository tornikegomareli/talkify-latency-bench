import Foundation
import Testing
@testable import LatencyBench

@Suite("Trigger event monitor")
@MainActor
struct TriggerEventMonitorTests {
  @Test("Parses fixed-input driver notifications")
  func parsesDriverNotification() throws {
    let notification = Notification(
      name: Notification.Name("com.talkify.latency-bench.trigger"),
      object: "BenchmarkStimulus",
      userInfo: [
        "trigger": "Fn",
        "edge": "released",
        "uptimeNanoseconds": NSNumber(value: UInt64(42))
      ]
    )

    let event = try #require(TriggerEventMonitor.driverEvent(from: notification))
    #expect(event.trigger == .function)
    #expect(event.edge == .released)
    #expect(event.uptimeNanoseconds == 42)
  }

  @Test("Parses stop-toggle driver notifications")
  func parsesStopToggleNotification() throws {
    let notification = Notification(
      name: Notification.Name("com.talkify.latency-bench.trigger"),
      object: "BenchmarkStimulus",
      userInfo: [
        "trigger": "⌥ Space",
        "edge": "released",
        "uptimeNanoseconds": NSNumber(value: UInt64(84))
      ]
    )

    let event = try #require(TriggerEventMonitor.driverEvent(from: notification))
    #expect(event.trigger == .optionSpace)
    #expect(event.edge == .released)
    #expect(event.uptimeNanoseconds == 84)
  }

  @Test("Parses modifier-only toggle notifications")
  func parsesModifierOnlyToggleNotification() throws {
    let notification = Notification(
      name: Notification.Name("com.talkify.latency-bench.trigger"),
      object: "BenchmarkStimulus",
      userInfo: [
        "trigger": "Left ⌥",
        "edge": "released",
        "uptimeNanoseconds": NSNumber(value: UInt64(105))
      ]
    )

    let event = try #require(TriggerEventMonitor.driverEvent(from: notification))
    #expect(event.trigger == .leftOption)
    #expect(event.edge == .released)
    #expect(event.uptimeNanoseconds == 105)
  }

  @Test("Parses superwhisper menu driver notifications")
  func parsesSuperwhisperMenuNotification() throws {
    let notification = Notification(
      name: Notification.Name("com.talkify.latency-bench.trigger"),
      object: "BenchmarkStimulus",
      userInfo: [
        "trigger": "superwhisper menu",
        "edge": "pressed",
        "uptimeNanoseconds": NSNumber(value: UInt64(126))
      ]
    )

    let event = try #require(TriggerEventMonitor.driverEvent(from: notification))
    #expect(event.trigger == .superwhisperMenu)
    #expect(event.edge == .pressed)
    #expect(event.uptimeNanoseconds == 126)
  }

  @Test("Rejects malformed driver notifications")
  func rejectsMalformedNotification() {
    let notification = Notification(
      name: Notification.Name("com.talkify.latency-bench.trigger"),
      object: "BenchmarkStimulus",
      userInfo: ["edge": "released"]
    )

    #expect(TriggerEventMonitor.driverEvent(from: notification) == nil)
  }

  @Test("Recognizes fixed-input arm commands")
  func recognizesArmCommand() {
    let notification = Notification(
      name: Notification.Name("com.talkify.latency-bench.command"),
      object: "BenchmarkStimulus",
      userInfo: ["command": "arm", "requestID": "request-1"]
    )

    #expect(TriggerEventMonitor.isArmCommand(notification))
    #expect(TriggerEventMonitor.armRequestID(from: notification) == "request-1")
  }
}
