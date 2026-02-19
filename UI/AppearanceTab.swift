import SwiftUI

struct AppearanceTab: View {
    @ObservedObject var appState: AppState

    @State private var particleCount: Double = 40
    @State private var particleSize: Double = 7
    @State private var particleOpacity: Double = 0.6
    @State private var selectedColor: Color = .white

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Particle Count")
                    Spacer()
                    Text("\(Int(particleCount))")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $particleCount, in: 20...80, step: 4) {
                    Text("Particle Count")
                }
                .onChange(of: particleCount) { _, newValue in
                    appState.dotRenderer.particleCount = Int(newValue)
                }

                HStack {
                    Text("Particle Size")
                    Spacer()
                    Text("\(Int(particleSize))px")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $particleSize, in: 4...12, step: 1) {
                    Text("Particle Size")
                }
                .onChange(of: particleSize) { _, newValue in
                    appState.dotRenderer.particleSize = CGFloat(newValue)
                }

                HStack {
                    Text("Opacity")
                    Spacer()
                    Text("\(Int(particleOpacity * 100))%")
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $particleOpacity, in: 0.2...0.8) {
                    Text("Opacity")
                }
                .onChange(of: particleOpacity) { _, newValue in
                    appState.dotRenderer.maxOpacity = CGFloat(newValue)
                }
            } header: {
                Text("Particles")
            }

            Section {
                HStack {
                    ColorPicker("Color", selection: $selectedColor)
                        .onChange(of: selectedColor) { _, newValue in
                            appState.dotRenderer.particleColor = NSColor(newValue)
                        }
                }

                // Preset colors
                HStack(spacing: 12) {
                    ForEach([Color.white, Color.black, Color.gray, Color.blue], id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                            )
                            .onTapGesture {
                                selectedColor = color
                                appState.dotRenderer.particleColor = NSColor(color)
                            }
                    }
                    Spacer()
                }
            } header: {
                Text("Color")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            particleCount = Double(appState.dotRenderer.particleCount)
            particleSize = Double(appState.dotRenderer.particleSize)
            particleOpacity = Double(appState.dotRenderer.maxOpacity)
            selectedColor = Color(nsColor: appState.dotRenderer.particleColor)
        }
    }
}
