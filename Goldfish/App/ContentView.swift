import SwiftUI

struct ContentView: View {
    @StateObject private var tuningStore = MotionTuningStore()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            SpriteKitView(tuningStore: tuningStore)
                .ignoresSafeArea()

            MotionTuningPanel(store: tuningStore)
                .padding(.top, 12)
                .padding(.trailing, 12)
        }
    }
}

final class MotionTuningStore: ObservableObject {
    enum Preset: String, CaseIterable, Identifiable {
        case natural
        case active
        case lazy

        var id: String { rawValue }
        var title: String {
            switch self {
            case .natural: return "自然"
            case .active: return "活跃"
            case .lazy: return "慵懒"
            }
        }
    }

    @Published var isEnabled: Bool = MotionTuningValues.default.enabled {
        didSet { markCustomIfNeeded() }
    }
    @Published var speedSmoothing: Double = Double(MotionTuningValues.default.speedSmoothing) {
        didSet { markCustomIfNeeded() }
    }
    @Published var tailAmplitudeScale: Double = Double(MotionTuningValues.default.tailAmplitudeScale) {
        didSet { markCustomIfNeeded() }
    }
    @Published var stateThresholdScale: Double = Double(MotionTuningValues.default.stateThresholdScale) {
        didSet { markCustomIfNeeded() }
    }

    @Published var motionGroupExpanded = true
    @Published var behaviorGroupExpanded = true
    @Published var selectedPreset: Preset? = .natural

    private var applyingPreset = false

    var currentTuning: MotionTuningValues {
        MotionTuningValues(
            enabled: isEnabled,
            speedSmoothing: CGFloat(speedSmoothing),
            tailAmplitudeScale: CGFloat(tailAmplitudeScale),
            stateThresholdScale: CGFloat(stateThresholdScale)
        )
    }

    func applyPreset(_ preset: Preset) {
        applyingPreset = true
        defer { applyingPreset = false }

        switch preset {
        case .natural:
            isEnabled = true
            speedSmoothing = 0.30
            tailAmplitudeScale = 1.00
            stateThresholdScale = 1.00
        case .active:
            isEnabled = true
            speedSmoothing = 0.20
            tailAmplitudeScale = 1.25
            stateThresholdScale = 0.85
        case .lazy:
            isEnabled = true
            speedSmoothing = 0.42
            tailAmplitudeScale = 0.78
            stateThresholdScale = 1.22
        }

        selectedPreset = preset
    }

    func resetToDefault() {
        applyPreset(.natural)
    }

    private func markCustomIfNeeded() {
        guard !applyingPreset else { return }
        selectedPreset = nil
    }
}

private struct MotionTuningPanel: View {
    @ObservedObject var store: MotionTuningStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("运动调参")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Toggle("", isOn: $store.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .scaleEffect(0.85)
            }

            HStack(spacing: 6) {
                ForEach(MotionTuningStore.Preset.allCases) { preset in
                    Button {
                        store.applyPreset(preset)
                    } label: {
                        Text(preset.title)
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(
                                (store.selectedPreset == preset ? Color.orange.opacity(0.35) : Color.white.opacity(0.08)),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            DisclosureGroup(isExpanded: $store.motionGroupExpanded) {
                VStack(spacing: 8) {
                    sliderRow(
                        title: "速度平滑",
                        value: $store.speedSmoothing,
                        range: 0.08...0.55,
                        step: 0.01
                    )
                    sliderRow(
                        title: "尾摆幅度",
                        value: $store.tailAmplitudeScale,
                        range: 0.6...1.7,
                        step: 0.01
                    )
                }
                .padding(.top, 4)
            } label: {
                Text("运动")
                    .font(.system(size: 12, weight: .semibold))
            }

            DisclosureGroup(isExpanded: $store.behaviorGroupExpanded) {
                VStack(spacing: 8) {
                    sliderRow(
                        title: "状态阈值",
                        value: $store.stateThresholdScale,
                        range: 0.7...1.5,
                        step: 0.01
                    )
                }
                .padding(.top, 4)
            } label: {
                Text("行为")
                    .font(.system(size: 12, weight: .semibold))
            }

            Button("重置默认") {
                store.resetToDefault()
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 280)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder
    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }
}
