import AppKit
import SwiftUI

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
  private let controller = LatencyBenchController()
  private var window: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApplication.shared.setActivationPolicy(.regular)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1_080, height: 780),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Talkify Latency Bench"
    window.minSize = NSSize(width: 940, height: 680)
    window.contentView = NSHostingView(rootView: LatencyBenchView(controller: controller))
    window.setFrameAutosaveName("LatencyBenchWindow")
    window.center()
    window.makeKeyAndOrderFront(nil)
    self.window = window

    controller.startMonitoring()
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    window?.makeKeyAndOrderFront(nil)
    return true
  }

  func applicationWillTerminate(_ notification: Notification) {
    controller.stopMonitoring()
  }
}

@main
struct LatencyBenchApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
