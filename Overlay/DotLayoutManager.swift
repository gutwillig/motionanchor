import AppKit
import Foundation

/// Manages dot placement and distribution across screens
final class DotLayoutManager {

    enum LayoutMode: String, CaseIterable {
        case edgesOnly = "Edges Only"
        case edgesAndCorners = "Edges + Corners"
        case custom = "Custom"
    }

    var layoutMode: LayoutMode = .edgesAndCorners
    var customPositions: [CGPoint] = []  // For custom layout mode

    /// Calculate dot home positions for a screen
    func calculatePositions(count: Int, for bounds: NSRect, inset: CGFloat = 60) -> [CGPoint] {
        switch layoutMode {
        case .edgesOnly:
            return edgeOnlyPositions(count: count, bounds: bounds, inset: inset)

        case .edgesAndCorners:
            return edgeAndCornerPositions(count: count, bounds: bounds, inset: inset)

        case .custom:
            return customPositions.isEmpty
                ? edgeAndCornerPositions(count: count, bounds: bounds, inset: inset)
                : customPositions
        }
    }

    // MARK: - Edge Only Layout

    private func edgeOnlyPositions(count: Int, bounds: NSRect, inset: CGFloat) -> [CGPoint] {
        var positions: [CGPoint] = []

        // Distribute dots only on the four edges, not corners
        let dotsPerEdge = max(1, count / 4)
        let remainder = count % 4

        // Top edge
        positions.append(contentsOf: positionsOnEdge(
            start: CGPoint(x: bounds.minX + inset * 2, y: bounds.maxY - inset),
            end: CGPoint(x: bounds.maxX - inset * 2, y: bounds.maxY - inset),
            count: dotsPerEdge + (remainder > 0 ? 1 : 0)
        ))

        // Right edge
        positions.append(contentsOf: positionsOnEdge(
            start: CGPoint(x: bounds.maxX - inset, y: bounds.maxY - inset * 2),
            end: CGPoint(x: bounds.maxX - inset, y: bounds.minY + inset * 2),
            count: dotsPerEdge + (remainder > 1 ? 1 : 0)
        ))

        // Bottom edge
        positions.append(contentsOf: positionsOnEdge(
            start: CGPoint(x: bounds.maxX - inset * 2, y: bounds.minY + inset),
            end: CGPoint(x: bounds.minX + inset * 2, y: bounds.minY + inset),
            count: dotsPerEdge + (remainder > 2 ? 1 : 0)
        ))

        // Left edge
        positions.append(contentsOf: positionsOnEdge(
            start: CGPoint(x: bounds.minX + inset, y: bounds.minY + inset * 2),
            end: CGPoint(x: bounds.minX + inset, y: bounds.maxY - inset * 2),
            count: dotsPerEdge
        ))

        return Array(positions.prefix(count))
    }

    // MARK: - Edge and Corner Layout

    private func edgeAndCornerPositions(count: Int, bounds: NSRect, inset: CGFloat) -> [CGPoint] {
        var positions: [CGPoint] = []

        // Add corners first
        let corners: [CGPoint] = [
            CGPoint(x: bounds.minX + inset, y: bounds.maxY - inset),  // Top-left
            CGPoint(x: bounds.maxX - inset, y: bounds.maxY - inset),  // Top-right
            CGPoint(x: bounds.maxX - inset, y: bounds.minY + inset),  // Bottom-right
            CGPoint(x: bounds.minX + inset, y: bounds.minY + inset)   // Bottom-left
        ]

        if count <= 4 {
            return Array(corners.prefix(count))
        }

        positions.append(contentsOf: corners)

        // Distribute remaining dots on edges
        let remaining = count - 4
        let perEdge = remaining / 4
        let extra = remaining % 4

        // Top edge
        if perEdge > 0 || extra > 0 {
            positions.append(contentsOf: positionsOnEdge(
                start: corners[0],
                end: corners[1],
                count: perEdge + (extra > 0 ? 1 : 0),
                excludeEndpoints: true
            ))
        }

        // Right edge
        if perEdge > 0 || extra > 1 {
            positions.append(contentsOf: positionsOnEdge(
                start: corners[1],
                end: corners[2],
                count: perEdge + (extra > 1 ? 1 : 0),
                excludeEndpoints: true
            ))
        }

        // Bottom edge
        if perEdge > 0 || extra > 2 {
            positions.append(contentsOf: positionsOnEdge(
                start: corners[2],
                end: corners[3],
                count: perEdge + (extra > 2 ? 1 : 0),
                excludeEndpoints: true
            ))
        }

        // Left edge
        if perEdge > 0 {
            positions.append(contentsOf: positionsOnEdge(
                start: corners[3],
                end: corners[0],
                count: perEdge,
                excludeEndpoints: true
            ))
        }

        return positions
    }

    // MARK: - Helpers

    private func positionsOnEdge(
        start: CGPoint,
        end: CGPoint,
        count: Int,
        excludeEndpoints: Bool = false
    ) -> [CGPoint] {
        guard count > 0 else { return [] }

        var positions: [CGPoint] = []

        let divisions = excludeEndpoints ? count + 1 : max(count - 1, 1)

        for i in 0..<count {
            let t = excludeEndpoints
                ? CGFloat(i + 1) / CGFloat(divisions)
                : (count == 1 ? 0.5 : CGFloat(i) / CGFloat(divisions))

            let x = start.x + (end.x - start.x) * t
            let y = start.y + (end.y - start.y) * t
            positions.append(CGPoint(x: x, y: y))
        }

        return positions
    }
}

// MARK: - Multi-Screen Support

extension DotLayoutManager {

    /// Calculate positions across all screens, distributing dots proportionally
    func calculatePositionsForAllScreens(totalCount: Int, inset: CGFloat = 60) -> [NSScreen: [CGPoint]] {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return [:] }

        var result: [NSScreen: [CGPoint]] = [:]

        // Calculate total perimeter across all screens
        let totalPerimeter = screens.reduce(0.0) { total, screen in
            let frame = screen.frame
            return total + 2 * frame.width + 2 * frame.height
        }

        for screen in screens {
            let frame = screen.frame
            let screenPerimeter = 2 * frame.width + 2 * frame.height
            let proportion = screenPerimeter / totalPerimeter
            let screenDotCount = max(4, Int(round(CGFloat(totalCount) * CGFloat(proportion))))

            result[screen] = calculatePositions(count: screenDotCount, for: frame, inset: inset)
        }

        return result
    }
}
