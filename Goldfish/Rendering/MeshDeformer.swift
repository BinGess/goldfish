import SpriteKit
import simd

/// Maps spine chain positions to SKWarpGeometryGrid destination vertices.
///
/// AXIS MAPPING (critical):
/// - The fish texture faces RIGHT: X-axis = head(left)-to-tail(right), Y-axis = dorsal(top)-to-belly(bottom)
/// - Warp grid COLUMNS map along X → along the spine (head-to-tail)
/// - Warp grid ROWS map along Y → across the body (lateral width)
/// - Vertex order: row-major, bottom-left (0,0) to top-right (1,1)
///
/// Grid: 5 columns × 3 rows = 6 vertex-columns × 4 vertex-rows = 24 vertices
final class MeshDeformer {

    /// Columns along the spine (head-to-tail resolution).
    let columns: Int
    /// Rows across the body (lateral resolution).
    let rows: Int

    /// Source positions (rest/identity state): computed once at init.
    let sourcePositions: [vector_float2]

    /// Fish body width profile (0=head, 1=tail) → width multiplier [0..1].
    private func bodyWidthProfile(_ t: CGFloat) -> CGFloat {
        if t < 0.15 {
            return 0.5 + 0.5 * (t / 0.15)   // Head taper
        } else if t < 0.35 {
            return 1.0                         // Widest section
        } else {
            let tailT = (t - 0.35) / 0.65
            return max(0.15, 1.0 - pow(tailT, 0.7) * 0.85)  // Taper to tail
        }
    }

    init(columns: Int = FishConfig.bodyWarpColumns, rows: Int = FishConfig.bodyWarpRows) {
        // Swap: use more columns (along spine) and fewer rows (lateral)
        self.columns = max(columns, rows)  // 5 along spine
        self.rows = min(columns, rows)     // 3 lateral

        let vertexCols = self.columns + 1
        let vertexRows = self.rows + 1
        var src: [vector_float2] = []
        // Row-major order: iterate rows (bottom to top), then columns (left to right)
        for row in 0..<vertexRows {
            for col in 0..<vertexCols {
                let x = Float(col) / Float(self.columns)
                let y = Float(row) / Float(self.rows)
                src.append(vector_float2(x, y))
            }
        }
        self.sourcePositions = src
    }

    /// Compute destination positions based on spine state.
    /// - Parameters:
    ///   - spinePositions: World-space positions of spine particles [0]=head, [N-1]=tail.
    ///   - spineAngles: Heading angle at each spine particle (radians).
    ///   - spriteFrame: The bounding rect of the fish sprite in scene coordinates.
    ///   - bodyWidth: Maximum visual width of the fish body (points).
    /// - Returns: Destination vertex positions in normalized [0,1] space.
    func computeDestinationPositions(
        spinePositions: [CGPoint],
        spineAngles: [CGFloat],
        spriteFrame: CGRect,
        bodyWidth: CGFloat
    ) -> [vector_float2] {

        let vertexCols = columns + 1  // Along spine
        let vertexRows = rows + 1     // Lateral

        // Pre-smooth spine angles to prevent mesh self-intersection during sharp turns
        let smoothedAngles = smoothSpineAngles(spineAngles)

        var destinations: [vector_float2] = []

        // Row-major: iterate rows (lateral, bottom→top), then columns (spine, head→tail)
        for row in 0..<vertexRows {
            // Row maps to lateral offset: row 0 = bottom (y=0), row max = top (y=1)
            // Lateral parameter: -0.5 (bottom) to +0.5 (top)
            let lateralT = CGFloat(row) / CGFloat(rows) - 0.5

            for col in 0..<vertexCols {
                // Column maps to spine parameter t: col 0 = left = head (x=0), col max = right = tail (x=1)
                let t = CGFloat(col) / CGFloat(columns)

                // Interpolate spine position and angle at this point
                let spinePos = interpolateSpine(at: t, positions: spinePositions)
                let angle = interpolateAngle(at: t, angles: smoothedAngles)

                // Perpendicular direction for lateral offset
                // Heading angle points from current segment toward head.
                // Perpendicular: rotate 90° counter-clockwise
                let perpX = -sin(angle)
                let perpY = cos(angle)

                // Width at this body position, reduce width during sharp curvature
                let curvatureFactor = computeCurvatureReduction(at: t, angles: smoothedAngles)
                let widthAtT = bodyWidthProfile(t) * bodyWidth * curvatureFactor
                let lateralOffset = lateralT * widthAtT

                // World position of this vertex
                let worldX = spinePos.x + perpX * lateralOffset
                let worldY = spinePos.y + perpY * lateralOffset

                // Convert to normalized sprite coordinates [0,1]
                let normX: CGFloat
                let normY: CGFloat
                if spriteFrame.width > 0 && spriteFrame.height > 0 {
                    normX = (worldX - spriteFrame.minX) / spriteFrame.width
                    normY = (worldY - spriteFrame.minY) / spriteFrame.height
                } else {
                    normX = CGFloat(col) / CGFloat(columns)
                    normY = CGFloat(row) / CGFloat(rows)
                }

                // Clamp to prevent extreme distortion
                let clampedX = Float(max(-0.3, min(1.3, normX)))
                let clampedY = Float(max(-0.3, min(1.3, normY)))

                destinations.append(vector_float2(clampedX, clampedY))
            }
        }

        return destinations
    }

    // MARK: - Angle Smoothing

    /// Smooth spine angles to prevent adjacent vertices from producing overlapping perpendicular offsets.
    /// Uses a 3-pass approach: (1) limit max angle difference between consecutive points,
    /// (2) apply Gaussian-like smoothing, (3) re-limit.
    private func smoothSpineAngles(_ angles: [CGFloat]) -> [CGFloat] {
        guard angles.count >= 2 else { return angles }

        var smoothed = angles
        let maxDiff: CGFloat = FishConfig.maxSpineBendAngle * 1.2  // Slightly more permissive for rendering

        // Pass 1: Clamp maximum angle difference between consecutive spine points (forward)
        for i in 1..<smoothed.count {
            var diff = smoothed[i] - smoothed[i - 1]
            if diff > .pi { diff -= 2 * .pi }
            if diff < -.pi { diff += 2 * .pi }
            if abs(diff) > maxDiff {
                let clampedDiff = diff > 0 ? maxDiff : -maxDiff
                smoothed[i] = smoothed[i - 1] + clampedDiff
            }
        }

        // Pass 2: 1-2-1 kernel smoothing (preserves head angle exactly)
        var blurred = smoothed
        for i in 1..<(smoothed.count - 1) {
            // Use angle-aware averaging to handle wrapping
            let prev = smoothed[i - 1]
            let curr = smoothed[i]
            let next = smoothed[i + 1]

            var diffPrev = prev - curr
            if diffPrev > .pi { diffPrev -= 2 * .pi }
            if diffPrev < -.pi { diffPrev += 2 * .pi }

            var diffNext = next - curr
            if diffNext > .pi { diffNext -= 2 * .pi }
            if diffNext < -.pi { diffNext += 2 * .pi }

            blurred[i] = curr + (diffPrev * 0.25 + diffNext * 0.25)
        }

        return blurred
    }

    /// Compute a width reduction factor based on local curvature.
    /// When the spine bends sharply, the body width is reduced to prevent mesh overlap.
    private func computeCurvatureReduction(at t: CGFloat, angles: [CGFloat]) -> CGFloat {
        guard angles.count >= 2 else { return 1.0 }

        let maxIdx = CGFloat(angles.count - 1)
        let rawIdx = t * maxIdx
        let idx0 = min(Int(rawIdx), angles.count - 1)
        let idx1 = min(idx0 + 1, angles.count - 1)

        if idx0 == idx1 { return 1.0 }

        var angleDiff = angles[idx1] - angles[idx0]
        if angleDiff > .pi { angleDiff -= 2 * .pi }
        if angleDiff < -.pi { angleDiff += 2 * .pi }

        // Reduce body width when curvature is high
        // At max bend angle (~0.7 rad / ~40°), reduce to 70% width
        let curvature = abs(angleDiff) / FishConfig.maxSpineBendAngle
        let reduction = max(0.7, 1.0 - curvature * 0.3)
        return reduction
    }

    /// Create a warp grid from the current spine state.
    func createWarpGrid(
        spinePositions: [CGPoint],
        spineAngles: [CGFloat],
        spriteFrame: CGRect,
        bodyWidth: CGFloat
    ) -> SKWarpGeometryGrid {
        let dst = computeDestinationPositions(
            spinePositions: spinePositions,
            spineAngles: spineAngles,
            spriteFrame: spriteFrame,
            bodyWidth: bodyWidth
        )
        return SKWarpGeometryGrid(
            columns: columns,
            rows: rows,
            sourcePositions: sourcePositions,
            destinationPositions: dst
        )
    }

    // MARK: - Interpolation

    /// Interpolate a position along the spine at parameter t (0=head, 1=tail).
    private func interpolateSpine(at t: CGFloat, positions: [CGPoint]) -> CGPoint {
        guard positions.count >= 2 else { return positions.first ?? .zero }

        let maxIdx = CGFloat(positions.count - 1)
        let rawIdx = t * maxIdx
        let idx0 = min(Int(rawIdx), positions.count - 1)
        let idx1 = min(idx0 + 1, positions.count - 1)
        let frac = rawIdx - CGFloat(idx0)

        let p0 = positions[idx0]
        let p1 = positions[idx1]
        return CGPoint(x: p0.x + (p1.x - p0.x) * frac,
                       y: p0.y + (p1.y - p0.y) * frac)
    }

    /// Interpolate an angle along the spine at parameter t.
    private func interpolateAngle(at t: CGFloat, angles: [CGFloat]) -> CGFloat {
        guard angles.count >= 2 else { return angles.first ?? 0 }

        let maxIdx = CGFloat(angles.count - 1)
        let rawIdx = t * maxIdx
        let idx0 = min(Int(rawIdx), angles.count - 1)
        let idx1 = min(idx0 + 1, angles.count - 1)
        let frac = rawIdx - CGFloat(idx0)

        let a0 = angles[idx0]
        let a1 = angles[idx1]

        // Shortest-path angle interpolation
        var diff = a1 - a0
        if diff > .pi { diff -= 2 * .pi }
        if diff < -.pi { diff += 2 * .pi }

        return a0 + diff * frac
    }
}
