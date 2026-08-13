import Charts
import SwiftUI

struct LatencyBenchView: View {
  @Bindable var controller: LatencyBenchController

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HeaderView(controller: controller)
        TrialSetupView(controller: controller)
        PhraseView(phrase: controller.selectedPhrase)
        MeasurementView(controller: controller)
        ResultSummaryView(result: controller.currentResult)
        ComparisonChart(summaries: controller.summaries)
      }
      .padding(28)
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .alert(
      "Latency Bench",
      isPresented: Binding(
        get: { controller.errorMessage != nil },
        set: { if !$0 { controller.errorMessage = nil } }
      )
    ) {
      Button("OK") { controller.errorMessage = nil }
    } message: {
      Text(controller.errorMessage ?? "")
    }
  }
}

private struct HeaderView: View {
  let controller: LatencyBenchController

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Talkify Latency Bench")
          .font(.largeTitle.weight(.bold))
        Text("Recording end → final visible text, measured with a monotonic clock")
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button("Open results", systemImage: "folder", action: controller.openResultsFolder)
    }
  }
}

private struct TrialSetupView: View {
  @Bindable var controller: LatencyBenchController

  var body: some View {
    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
      GridRow {
        Text("Engine")
        Picker("Engine", selection: $controller.engine) {
          ForEach(controller.engines, id: \.self) { Text($0) }
        }
        .labelsHidden()

        Text("Version")
        TextField("Version", text: $controller.engineVersion)
      }

      GridRow {
        Text("Mode")
        TextField("Mode or model", text: $controller.mode)

        Text("Trigger")
        Picker("Trigger", selection: $controller.trigger) {
          ForEach(BenchmarkTrigger.allCases) { trigger in
            Text(trigger.rawValue).tag(trigger)
          }
        }
        .labelsHidden()
      }

      GridRow {
        Text("Phrase")
        Picker("Phrase", selection: $controller.selectedPhraseID) {
          ForEach(BenchmarkPhrases.all) { phrase in
            Text(phrase.title).tag(phrase.id)
          }
        }
        .labelsHidden()

        HStack {
          Button("Arm trial", systemImage: "record.circle", action: controller.armTrial)
            .keyboardShortcut(.return, modifiers: [.command])
          Button(
            "Run fixed input",
            systemImage: "waveform.and.mic",
            action: controller.runFixedStimulus
          )
          .buttonStyle(.borderedProminent)
          .disabled(controller.isStimulusRunning || controller.trigger.driverArgument == nil)
        }
        .controlSize(.large)
      }
    }
    .padding(18)
    .background(.background.secondary, in: .rect(cornerRadius: 16))
  }
}

private struct PhraseView: View {
  let phrase: BenchmarkPhrase

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Speak this exact phrase")
        .font(.headline)
      Text(phrase.text)
        .font(.title2)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(18)
    .background(Color.accentColor.opacity(0.08), in: .rect(cornerRadius: 16))
  }
}

private struct MeasurementView: View {
  let controller: LatencyBenchController

  var body: some View {
    HStack(spacing: 20) {
      BenchmarkTextEditor(
        focusRequestID: controller.focusRequestID,
        onChange: controller.editorChanged
      )
      .frame(minHeight: 180)
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(statusColor.opacity(0.8), lineWidth: 2)
          .allowsHitTesting(false)
      }
      .compositingGroup()
      .clipShape(.rect(cornerRadius: 12))

      TimerReadout(controller: controller)
        .frame(width: 260)
    }
  }

  private var statusColor: Color {
    switch controller.machine.state.phase {
    case .recording:
      .blue
    case .released, .settling:
      .orange
    case .completed:
      .green
    case .idle, .armed:
      .secondary
    }
  }
}

private struct TimerReadout: View {
  let controller: LatencyBenchController

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1.0 / 60.0)) { _ in
      let milliseconds = controller.liveMilliseconds(
        atNanoseconds: DispatchTime.now().uptimeNanoseconds
      )
      VStack(spacing: 12) {
        Circle()
          .fill(statusColor)
          .frame(width: 14, height: 14)
        Text(controller.statusText)
          .font(.headline)
          .multilineTextAlignment(.center)
        Text(milliseconds.formatted(.number.precision(.fractionLength(0))))
          .font(.system(size: 60, weight: .bold, design: .rounded))
          .monospacedDigit()
          .contentTransition(.numericText())
        Text("milliseconds")
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding()
      .background(.background.secondary, in: .rect(cornerRadius: 16))
    }
  }

  private var statusColor: Color {
    switch controller.machine.state.phase {
    case .recording:
      .blue
    case .released, .settling:
      .orange
    case .completed:
      .green
    case .idle, .armed:
      .secondary
    }
  }
}

private struct ResultSummaryView: View {
  let result: BenchmarkResult?

  var body: some View {
    HStack(spacing: 12) {
      MetricCard(
        title: "First text",
        value: result.map { "\($0.releaseToFirstTextMilliseconds.formatted(.number.precision(.fractionLength(0)))) ms" } ?? "—"
      )
      MetricCard(
        title: "Final text",
        value: result.map { "\($0.releaseToFinalTextMilliseconds.formatted(.number.precision(.fractionLength(0)))) ms" } ?? "—"
      )
      MetricCard(
        title: "Accuracy",
        value: result.map { $0.accuracy.formatted(.percent.precision(.fractionLength(0))) } ?? "—"
      )
      MetricCard(
        title: "Trial",
        value: result.map { "#\($0.trialNumber)" } ?? "—"
      )
    }
  }
}

private struct MetricCard: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.title2.bold())
        .monospacedDigit()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(.background.secondary, in: .rect(cornerRadius: 14))
  }
}

private struct ComparisonChart: View {
  let summaries: [BenchmarkSummary]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Median by engine")
        .font(.title2.bold())

      if summaries.isEmpty {
        ContentUnavailableView(
          "No completed trials",
          systemImage: "chart.bar",
          description: Text("Run the same phrase for each engine.")
        )
        .frame(height: 180)
      } else {
        Chart(summaries) { summary in
          BarMark(
            x: .value("Engine", summary.engine),
            y: .value("Median milliseconds", summary.medianMilliseconds)
          )
          .foregroundStyle(by: .value("Engine", summary.engine))
          .annotation(position: .top) {
            Text("\(summary.medianMilliseconds.formatted(.number.precision(.fractionLength(0)))) ms")
              .font(.caption.bold())
          }
        }
        .chartLegend(.hidden)
        .frame(height: 220)
      }
    }
    .padding(18)
    .background(.background.secondary, in: .rect(cornerRadius: 16))
  }
}
