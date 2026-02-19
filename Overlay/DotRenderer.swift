import AppKit
import Foundation
import Combine

/// A single particle in the flow system
struct Particle {
    var position: CGPoint
    var velocity: CGPoint
    var opacity: CGFloat
    var edge: Edge  // Which edge this particle belongs to

    enum Edge {
        case top, bottom, left, right
    }
}

/// Renders flowing particles that respond to motion
final class DotRenderer: ObservableObject {

    // MARK: - Settings

    var particleCount: Int = 30 {
        didSet {
            if particleCount != oldValue {
                particles.removeAll()  // Force re-initialization
            }
        }
    }
    var particleSize: CGFloat = 30
    var particleColor: NSColor = .white
    var maxOpacity: CGFloat = 0.6

    // Physics
    var friction: CGFloat = 0.92  // Velocity decay per frame
    var motionScale: CGFloat = 8.0  // How much motion affects particles

    // MARK: - State

    private var particles: [Particle] = []
    private var screenBounds: NSRect = .zero
    private var currentMotion: CGPoint = .zero  // Current motion input
    private var smoothedMotion: CGPoint = .zero  // Smoothed for display

    // Margin where particles live (outer 20% on each side)
    private let marginPercent: CGFloat = 0.20

    // MARK: - Public Interface

    /// Current offset from motion (called by AppState)
    var currentOffset: CGPoint {
        get { currentMotion }
        set {
            currentMotion = CGPoint(
                x: newValue.x * motionScale,
                y: newValue.y * motionScale
            )
        }
    }

    var currentYawOffset: CGFloat = 0  // Not used in particle system

    // MARK: - Initialization

    func initializeParticles(for bounds: NSRect) {
        guard bounds != screenBounds || particles.isEmpty else { return }
        screenBounds = bounds
        particles.removeAll()

        let particlesPerEdge = particleCount / 4

        // Create particles along each edge
        for i in 0..<particlesPerEdge {
            let t = CGFloat(i) / CGFloat(particlesPerEdge)

            // Top edge
            particles.append(Particle(
                position: CGPoint(x: bounds.minX + t * bounds.width, y: bounds.maxY - 30),
                velocity: .zero,
                opacity: maxOpacity * CGFloat.random(in: 0.5...1.0),
                edge: .top
            ))

            // Bottom edge
            particles.append(Particle(
                position: CGPoint(x: bounds.minX + t * bounds.width, y: bounds.minY + 30),
                velocity: .zero,
                opacity: maxOpacity * CGFloat.random(in: 0.5...1.0),
                edge: .bottom
            ))

            // Left edge
            particles.append(Particle(
                position: CGPoint(x: bounds.minX + 30, y: bounds.minY + t * bounds.height),
                velocity: .zero,
                opacity: maxOpacity * CGFloat.random(in: 0.5...1.0),
                edge: .left
            ))

            // Right edge
            particles.append(Particle(
                position: CGPoint(x: bounds.maxX - 30, y: bounds.minY + t * bounds.height),
                velocity: .zero,
                opacity: maxOpacity * CGFloat.random(in: 0.5...1.0),
                edge: .right
            ))
        }
    }

    // MARK: - Physics Update

    func updateParticles() {
        guard !particles.isEmpty else { return }

        // Decay current motion toward zero (for when stream stops)
        currentMotion.x *= 0.95
        currentMotion.y *= 0.95

        // Smooth the motion input
        smoothedMotion.x = smoothedMotion.x * 0.8 + currentMotion.x * 0.2
        smoothedMotion.y = smoothedMotion.y * 0.8 + currentMotion.y * 0.2

        // Zero out tiny values
        if abs(smoothedMotion.x) < 0.01 { smoothedMotion.x = 0 }
        if abs(smoothedMotion.y) < 0.01 { smoothedMotion.y = 0 }

        let marginX = screenBounds.width * marginPercent
        let marginY = screenBounds.height * marginPercent
        let innerLeft = screenBounds.minX + marginX
        let innerRight = screenBounds.maxX - marginX
        let innerTop = screenBounds.maxY - marginY
        let innerBottom = screenBounds.minY + marginY

        for i in 0..<particles.count {
            var p = particles[i]

            // Apply motion as force
            p.velocity.x += smoothedMotion.x * 0.1
            p.velocity.y += smoothedMotion.y * 0.1

            // Apply friction
            p.velocity.x *= friction
            p.velocity.y *= friction

            // Update position
            p.position.x += p.velocity.x
            p.position.y += p.velocity.y

            // Calculate opacity based on distance from center
            let centerX = screenBounds.midX
            let centerY = screenBounds.midY
            let distFromCenterX = abs(p.position.x - centerX) / (screenBounds.width / 2)
            let distFromCenterY = abs(p.position.y - centerY) / (screenBounds.height / 2)
            let distFromCenter = max(distFromCenterX, distFromCenterY)

            // Fade out as particles approach center (inner 60%)
            if distFromCenter < 0.4 {
                p.opacity = 0
            } else if distFromCenter < 0.6 {
                p.opacity = maxOpacity * (distFromCenter - 0.4) / 0.2
            } else {
                p.opacity = maxOpacity
            }

            // Respawn particles that go too far
            let respawnMargin: CGFloat = 50
            var needsRespawn = false

            switch p.edge {
            case .left, .right:
                // Horizontal particles: respawn if they go past center or off-screen
                if p.position.x < screenBounds.minX - respawnMargin ||
                   p.position.x > screenBounds.maxX + respawnMargin ||
                   (p.position.x > innerLeft && p.position.x < innerRight) {
                    needsRespawn = true
                }
            case .top, .bottom:
                // Vertical particles: respawn if they go past center or off-screen
                if p.position.y < screenBounds.minY - respawnMargin ||
                   p.position.y > screenBounds.maxY + respawnMargin ||
                   (p.position.y > innerBottom && p.position.y < innerTop) {
                    needsRespawn = true
                }
            }

            if needsRespawn {
                p = respawnParticle(p)
            }

            particles[i] = p
        }
    }

    private func respawnParticle(_ particle: Particle) -> Particle {
        var p = particle
        p.velocity = .zero
        p.opacity = maxOpacity * CGFloat.random(in: 0.5...1.0)

        let margin: CGFloat = 30

        switch p.edge {
        case .top:
            p.position = CGPoint(
                x: CGFloat.random(in: screenBounds.minX...screenBounds.maxX),
                y: screenBounds.maxY - margin + CGFloat.random(in: -10...10)
            )
        case .bottom:
            p.position = CGPoint(
                x: CGFloat.random(in: screenBounds.minX...screenBounds.maxX),
                y: screenBounds.minY + margin + CGFloat.random(in: -10...10)
            )
        case .left:
            p.position = CGPoint(
                x: screenBounds.minX + margin + CGFloat.random(in: -10...10),
                y: CGFloat.random(in: screenBounds.minY...screenBounds.maxY)
            )
        case .right:
            p.position = CGPoint(
                x: screenBounds.maxX - margin + CGFloat.random(in: -10...10),
                y: CGFloat.random(in: screenBounds.minY...screenBounds.maxY)
            )
        }

        return p
    }

    // MARK: - Drawing

    func drawDots(in context: CGContext, bounds: NSRect) {
        initializeParticles(for: bounds)
        updateParticles()

        let centerX = bounds.midX
        let centerY = bounds.midY

        for particle in particles {
            guard particle.opacity > 0.01 else { continue }

            // Calculate distance from center (0 = center, 1 = edge)
            let distFromCenterX = abs(particle.position.x - centerX) / (bounds.width / 2)
            let distFromCenterY = abs(particle.position.y - centerY) / (bounds.height / 2)
            let distFromCenter = max(distFromCenterX, distFromCenterY)

            // Scale size based on distance (smaller near center)
            // Range: 50% at center to 100% at edge, with squared falloff for more dramatic effect
            let sizeScale = 0.5 + 0.5 * distFromCenter * distFromCenter
            let currentSize = particleSize * sizeScale

            let color = particleColor.withAlphaComponent(particle.opacity)
            context.setFillColor(color.cgColor)

            let rect = CGRect(
                x: particle.position.x - currentSize / 2,
                y: particle.position.y - currentSize / 2,
                width: currentSize,
                height: currentSize
            )

            context.fillEllipse(in: rect)
        }
    }

    // MARK: - Legacy (unused but kept for compatibility)

    func startReturnToHome() {}
    func updateReturnToHome() -> Bool { return true }
}

// MARK: - NSView for Drawing Dots

final class DotOverlayView: NSView {

    var dotRenderer: DotRenderer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        guard let renderer = dotRenderer else { return }

        // Clear background (transparent)
        context.clear(bounds)

        // Draw dots
        renderer.drawDots(in: context, bounds: bounds)
    }
}
