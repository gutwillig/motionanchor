import SwiftUI

struct SettingsView: View {
    @ObservedObject var motionManager: MotionSensorManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("samplingRate") private var samplingRateSelection: Int = 60
    @AppStorage("lowPowerMode") private var lowPowerMode: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Sampling Rate", selection: $samplingRateSelection) {
                        Text("30 Hz (Low Power)").tag(30)
                        Text("60 Hz (Default)").tag(60)
                    }
                    .onChange(of: samplingRateSelection) { _, newValue in
                        motionManager.setSamplingRate(Double(newValue))
                    }
                } header: {
                    Text("Performance")
                } footer: {
                    Text("Higher sampling rate provides smoother motion tracking but uses more battery.")
                }

                Section {
                    Toggle("Low Power Mode", isOn: $lowPowerMode)
                } header: {
                    Text("Battery")
                } footer: {
                    Text("Automatically reduces sampling rate when battery is low.")
                }

                Section {
                    HStack {
                        Text("Calibration Status")
                        Spacer()
                        Text(motionManager.isCalibrated ? "Calibrated" : "Not Calibrated")
                            .foregroundColor(motionManager.isCalibrated ? .green : .orange)
                    }

                    Button("Reset Calibration") {
                        motionManager.resetCalibration()
                    }
                    .foregroundColor(.red)
                } header: {
                    Text("Sensor")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Device Motion")
                        Spacer()
                        Text(motionManager.isDeviceMotionAvailable ? "Available" : "Not Available")
                            .foregroundColor(motionManager.isDeviceMotionAvailable ? .green : .red)
                    }
                } header: {
                    Text("About")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How It Works")
                            .font(.headline)

                        Text("MotionAnchor streams your phone's motion sensor data to your Mac, where it moves peripheral dots to match vehicle motion. This reduces motion sickness by giving your eyes visual cues that match what your inner ear senses.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView(motionManager: MotionSensorManager())
}
