import SwiftUI

struct CalibrationView: View {
    @ObservedObject var motionManager: MotionSensorManager
    let onComplete: () -> Void

    @State private var calibrationStep: CalibrationStep = .placement
    @State private var countdown: Int = 3
    @State private var isCalibrating = false

    enum CalibrationStep {
        case placement
        case countdown
        case calibrating
        case complete
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Illustration
                CalibrationIllustration(step: calibrationStep)

                // Instructions
                VStack(spacing: 12) {
                    Text(instructionTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    Text(instructionSubtitle)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                // Action button
                if calibrationStep == .placement {
                    Button {
                        startCalibration()
                    } label: {
                        Text("Calibrate")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                } else if calibrationStep == .countdown {
                    Text("\(countdown)")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(.blue)
                } else if calibrationStep == .complete {
                    Button {
                        UserDefaults.standard.set(true, forKey: "hasCalibrated")
                        onComplete()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        onComplete()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    private var instructionTitle: String {
        switch calibrationStep {
        case .placement:
            return "Place Your Phone"
        case .countdown:
            return "Hold Still"
        case .calibrating:
            return "Calibrating..."
        case .complete:
            return "Calibration Complete"
        }
    }

    private var instructionSubtitle: String {
        switch calibrationStep {
        case .placement:
            return "Put your phone in a stable position in your vehicle - a cupholder, mount, or flat surface works best."
        case .countdown:
            return "Keep the phone still while we capture the reference orientation."
        case .calibrating:
            return "Measuring sensor baseline..."
        case .complete:
            return "Your phone is calibrated. Motion tracking will now work regardless of phone orientation."
        }
    }

    private func startCalibration() {
        calibrationStep = .countdown
        countdown = 3

        // Countdown
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdown -= 1
            if countdown == 0 {
                timer.invalidate()
                performCalibration()
            }
        }
    }

    private func performCalibration() {
        calibrationStep = .calibrating

        // Use background calibration - this won't interrupt any existing streaming
        motionManager.calibrateInBackground {
            DispatchQueue.main.async {
                calibrationStep = .complete
            }
        }
    }
}

// MARK: - Calibration Illustration

struct CalibrationIllustration: View {
    let step: CalibrationView.CalibrationStep

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(backgroundColor.opacity(0.2))
                .frame(width: 200, height: 200)

            // Icon
            Image(systemName: iconName)
                .font(.system(size: 80))
                .foregroundColor(backgroundColor)
                .symbolEffect(.pulse, options: .repeating, isActive: step == .calibrating)
        }
    }

    private var iconName: String {
        switch step {
        case .placement:
            return "iphone.gen3"
        case .countdown:
            return "hand.raised"
        case .calibrating:
            return "gyroscope"
        case .complete:
            return "checkmark.circle.fill"
        }
    }

    private var backgroundColor: Color {
        switch step {
        case .placement:
            return .blue
        case .countdown:
            return .orange
        case .calibrating:
            return .purple
        case .complete:
            return .green
        }
    }
}

#Preview {
    CalibrationView(motionManager: MotionSensorManager()) {}
}
