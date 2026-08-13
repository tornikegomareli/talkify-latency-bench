import AppKit
import Foundation

@MainActor
final class TriggerEventMonitor: NSObject {
  enum Edge: Equatable, Sendable {
    case pressed
    case released
  }

  struct Event: Sendable {
    let trigger: BenchmarkTrigger
    let edge: Edge
    let uptimeNanoseconds: UInt64
  }

  private var localMonitor: Any?
  private var globalMonitor: Any?
  private var handler: ((Event) -> Void)?
  private var armHandler: (() -> Void)?
  private var functionIsDown = false
  private var f13IsDown = false
  private var optionSpaceIsRecording = false
  private var isObservingDriver = false

  private static let driverNotification = Notification.Name(
    "com.talkify.latency-bench.trigger"
  )
  private static let commandNotification = Notification.Name(
    "com.talkify.latency-bench.command"
  )
  private static let commandAcknowledgement = Notification.Name(
    "com.talkify.latency-bench.command-acknowledgement"
  )

  func start(
    handler: @escaping (Event) -> Void,
    armHandler: @escaping () -> Void
  ) {
    guard localMonitor == nil, globalMonitor == nil else { return }
    self.handler = handler
    self.armHandler = armHandler
    let mask: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]

    localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
      self?.capture(event)
      return event
    }
    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
      self?.capture(event)
    }
    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(captureDriverNotification(_:)),
      name: Self.driverNotification,
      object: "BenchmarkStimulus"
    )
    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(captureDriverCommand(_:)),
      name: Self.commandNotification,
      object: "BenchmarkStimulus"
    )
    isObservingDriver = true
  }

  func stop() {
    if let localMonitor {
      NSEvent.removeMonitor(localMonitor)
    }
    if let globalMonitor {
      NSEvent.removeMonitor(globalMonitor)
    }
    localMonitor = nil
    globalMonitor = nil
    if isObservingDriver {
      DistributedNotificationCenter.default().removeObserver(
        self,
        name: Self.driverNotification,
        object: "BenchmarkStimulus"
      )
      DistributedNotificationCenter.default().removeObserver(
        self,
        name: Self.commandNotification,
        object: "BenchmarkStimulus"
      )
      isObservingDriver = false
    }
    handler = nil
    armHandler = nil
    functionIsDown = false
    f13IsDown = false
    optionSpaceIsRecording = false
  }

  static func driverEvent(from notification: Notification) -> Event? {
    guard notification.name == driverNotification,
          notification.object as? String == "BenchmarkStimulus",
          let triggerValue = notification.userInfo?["trigger"] as? String,
          let trigger = BenchmarkTrigger(rawValue: triggerValue),
          let edgeValue = notification.userInfo?["edge"] as? String,
          let instant = notification.userInfo?["uptimeNanoseconds"] as? NSNumber else {
      return nil
    }

    let edge: Edge
    switch edgeValue {
    case "pressed":
      edge = .pressed
    case "released":
      edge = .released
    default:
      return nil
    }
    return Event(
      trigger: trigger,
      edge: edge,
      uptimeNanoseconds: instant.uint64Value
    )
  }

  static func isArmCommand(_ notification: Notification) -> Bool {
    notification.name == commandNotification
      && notification.object as? String == "BenchmarkStimulus"
      && notification.userInfo?["command"] as? String == "arm"
  }

  static func armRequestID(from notification: Notification) -> String? {
    guard isArmCommand(notification) else { return nil }
    return notification.userInfo?["requestID"] as? String
  }

  @objc private func captureDriverNotification(_ notification: Notification) {
    guard let event = Self.driverEvent(from: notification) else { return }
    handler?(event)
  }

  @objc private func captureDriverCommand(_ notification: Notification) {
    guard let requestID = Self.armRequestID(from: notification) else { return }
    armHandler?()
    DistributedNotificationCenter.default().postNotificationName(
      Self.commandAcknowledgement,
      object: "LatencyBench",
      userInfo: ["requestID": requestID],
      deliverImmediately: true
    )
  }

  private func capture(_ event: NSEvent) {
    let instant = DispatchTime.now().uptimeNanoseconds

    if event.type == .flagsChanged {
      let isDown = event.modifierFlags.contains(.function)
      guard isDown != functionIsDown else { return }
      functionIsDown = isDown
      handler?(
        Event(
          trigger: .function,
          edge: isDown ? .pressed : .released,
          uptimeNanoseconds: instant
        )
      )
      return
    }

    if event.type == .keyDown,
       !event.isARepeat,
       event.keyCode == 49,
       event.modifierFlags.contains(.option) {
      optionSpaceIsRecording.toggle()
      handler?(
        Event(
          trigger: .optionSpace,
          edge: optionSpaceIsRecording ? .pressed : .released,
          uptimeNanoseconds: instant
        )
      )
      return
    }

    guard event.keyCode == 105 else { return }
    let isDown = event.type == .keyDown
    guard isDown != f13IsDown else { return }
    f13IsDown = isDown
    handler?(
      Event(
        trigger: .f13,
        edge: isDown ? .pressed : .released,
        uptimeNanoseconds: instant
      )
    )
  }
}
