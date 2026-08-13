import AppKit
import SwiftUI

struct BenchmarkTextEditor: NSViewRepresentable {
  let focusRequestID: Int
  let onChange: (String, UInt64) -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(onChange: onChange)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSTextView.scrollableTextView()
    guard let textView = scrollView.documentView as? NSTextView else { return scrollView }

    textView.delegate = context.coordinator
    textView.font = .systemFont(ofSize: 24, weight: .regular)
    textView.textContainerInset = NSSize(width: 18, height: 18)
    textView.isRichText = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.setAccessibilityIdentifier("latency-benchmark-input")
    context.coordinator.textView = textView
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    context.coordinator.onChange = onChange
    guard focusRequestID != context.coordinator.lastFocusRequestID,
          let textView = context.coordinator.textView else { return }

    context.coordinator.lastFocusRequestID = focusRequestID
    textView.string = ""
    DispatchQueue.main.async {
      textView.window?.makeFirstResponder(textView)
    }
  }

  @MainActor
  final class Coordinator: NSObject, NSTextViewDelegate {
    weak var textView: NSTextView?
    var lastFocusRequestID = 0
    var onChange: (String, UInt64) -> Void

    init(onChange: @escaping (String, UInt64) -> Void) {
      self.onChange = onChange
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      onChange(textView.string, DispatchTime.now().uptimeNanoseconds)
    }
  }
}
