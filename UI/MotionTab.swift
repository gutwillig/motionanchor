import SwiftUI

struct MotionTab: View {
    @ObservedObject var appState: AppState

    @State private var overallSensitivity: Double = 1.0
    @State private var smoothing: Double = 0.3
    @State private var maxDisplacement: Double = 150

    @State private var showAdvanced = false
    @State private var lateralGain: Double = 300
    @State private var longitudinalGain: Double = 200
    @State private var verticalGain: Double = 100
    @State private var yawGain: Double = 50

    @State private var isTestModeActive = false

    var body: some View {
        Form {
            Section {
                // Overall sensitivity
                HStack {
                    Text("Overall Sensitivity")
                    Spacer()
                    Text(String(format: "%.1fx", overallSensitivity))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $overallSensitivity, in: 0.5...3.0, step: 0.1) {
                    Text("Sensitivity")
                }
                .onChange(of: overallSensitivity) { _, newValue in
                    appState.motionProcessor.sensitivityMultiplier = newValue
                }

                // Sensitivity presets
                HStack {
                    Text("Presets:")
                        .foregroundColor(.secondary)
                    Spacer()

                    Button("Low") {
                        overallSensitivity = 0.5
                        appState.setSensitivityPreset(.low)
                    }
                    .buttonStyle(.bordered)

                    Button("Medium") {
                        overallSensitivity = 1.0
                        appState.setSensitivityPreset(.medium)
                    }
                    .buttonStyle(.bordered)

                    Button("High") {
                        overallSensitivity = 1.5
                        appState.setSensitivityPreset(.high)
                    }
                    .buttonStyle(.bordered)
                }
            } header: {
                Text("Sensitivity")
            }

            Section {
                HStack {
                    Text("Smoothing")
                    Spacer()
                    Text(String(format: "%.2f", smoothing))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $smoothing, in: 0.1...0.8) {
                    Text("Smoothing")
                }
                .onChange(of: smoothing) { _, newValue in
                    appState.motionProcessor.smoothingAlpha = newValue
                }

                Text("Lower values = smoother but laggier. Higher values = snappier but jittery.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Max Displacement")
                    Spacer()
                    Text("\(Int(maxDisplacement))px")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $maxDisplacement, in: 50...300, step: 10) {
                    Text("Max Displacement")
                }
                .onChange(of: maxDisplacement) { _, newValue in
                    appState.motionProcessor.maxDisplacement = CGFloat(newValue)
                }
            } header: {
                Text("Response")
            }

            Section {
                DisclosureGroup("Advanced Axis Tuning", isExpanded: $showAdvanced) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Lateral
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Lateral (left/right)")
                                Spacer()
                                Text("\(Int(lateralGain)) px/g")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $lateralGain, in: 50...600, step: 25)
                                .onChange(of: lateralGain) { _, newValue in
                                    appState.motionProcessor.lateralGain = newValue
                                }
                        }

                        // Longitudinal
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Longitudinal (forward/back)")
                                Spacer()
                                Text("\(Int(longitudinalGain)) px/g")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $longitudinalGain, in: 50...500, step: 25)
                                .onChange(of: longitudinalGain) { _, newValue in
                                    appState.motionProcessor.longitudinalGain = newValue
                                }
                        }

                        // Vertical
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Vertical (up/down)")
                                Spacer()
                                Text("\(Int(verticalGain)) px/g")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $verticalGain, in: 0...300, step: 25)
                                .onChange(of: verticalGain) { _, newValue in
                                    appState.motionProcessor.verticalGain = newValue
                                }
                        }

                        // Yaw
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Yaw (rotation)")
                                Spacer()
                                Text("\(Int(yawGain)) px/rad")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $yawGain, in: 0...150, step: 5)
                                .onChange(of: yawGain) { _, newValue in
                                    appState.motionProcessor.yawGain = newValue
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            } header: {
                Text("Fine Tuning")
            }

            Section {
                Toggle("Test Mode", isOn: $isTestModeActive)
                    .onChange(of: isTestModeActive) { _, newValue in
                        if newValue {
                            appState.startTestMode()
                        } else {
                            appState.stopTestMode()
                        }
                    }

                Text("Simulates gentle car motion to preview dot behavior without phone connected.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Testing")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            overallSensitivity = appState.motionProcessor.sensitivityMultiplier
            smoothing = appState.motionProcessor.smoothingAlpha
            maxDisplacement = Double(appState.motionProcessor.maxDisplacement)
            lateralGain = appState.motionProcessor.lateralGain
            longitudinalGain = appState.motionProcessor.longitudinalGain
            verticalGain = appState.motionProcessor.verticalGain
            yawGain = appState.motionProcessor.yawGain
        }
    }
}
