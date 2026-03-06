import SpriteKit

/// Assembles and manages the layered fish sprite with warp-grid deformation.
///
/// Layer architecture:
///   - bodySprite  (zPosition  0): oval body textured via SKWarpGeometryGrid.
///   - tailSprite  (zPosition +1): separate tail-fin sprite anchored at the N-2 spine
///                                 particle. Renders IN FRONT to cover the body's thin
///                                 caudal peduncle end. NOT warped; rotates per frame.
final class FishSpriteAssembler {

    // MARK: - Sprite Nodes

    /// Root node containing all fish visual elements.
    let rootNode: SKNode

    /// Body sprite with warp geometry applied.
    private let bodySprite: SKSpriteNode

    /// Tail fin sprite — independent of warp, follows last spine segment angle.
    private let tailSprite: SKSpriteNode?

    /// Mesh deformer that maps spine → warp grid.
    private let meshDeformer: MeshDeformer

    // MARK: - Dimensions

    let bodyWidth: CGFloat
    let bodyLength: CGFloat

    // MARK: - Smoothing State

    /// Smoothed bounding frame to suppress rendering jitter.
    private var smoothedFrame: CGRect?

    /// Smoothed tail angle to prevent per-frame rotation jitter.
    private var smoothedTailAngle: CGFloat?

    // MARK: - Init

    /// - Parameters:
    ///   - bodyTexture: Texture for the fish body (head-left, tail-right, no caudal fin).
    ///   - tailTexture: Optional separate caudal fin texture (root at left-center, fan opens right).
    ///   - bodyLength:  Spine arc length in points.
    ///   - bodyWidth:   Maximum body width in points.
    init(
        bodyTexture: SKTexture,
        tailTexture: SKTexture? = nil,
        bodyLength: CGFloat = 240,
        bodyWidth: CGFloat = 90
    ) {
        self.bodyLength = bodyLength
        self.bodyWidth  = bodyWidth
        self.meshDeformer = MeshDeformer()

        // Root node at world origin; children are positioned in local space.
        rootNode = SKNode()
        rootNode.name = "fishRoot"
        rootNode.zPosition = 100

        // --- Body sprite ---
        bodySprite = SKSpriteNode(texture: bodyTexture)
        bodySprite.size = CGSize(width: bodyLength * 1.5, height: bodyLength * 1.5)
        bodySprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        bodySprite.zPosition = 0
        let initialGrid = SKWarpGeometryGrid(
            columns: meshDeformer.columns,
            rows: meshDeformer.rows
        )
        bodySprite.warpGeometry = initialGrid
        rootNode.addChild(bodySprite)

        // --- Tail fin sprite ---
        if let tailTex = tailTexture {
            let tail = SKSpriteNode(texture: tailTex)
            // Width  = how far the fin sticks out from the peduncle (along fin axis)
            // Height = fan spread (perpendicular to fin axis)
            // Ratio 1.30 : 1.20 ≈ 1.083 matches the cropped fish_tail.png aspect ratio (1748:1621 ≈ 1.079)
            tail.size = CGSize(width: bodyWidth * 1.30, height: bodyWidth * 1.20)
            // Anchor at the ROOT of the fin (left-center of the image),
            // so rotation pivots around the peduncle attachment point.
            tail.anchorPoint = CGPoint(x: 0.0, y: 0.5)
            // Render IN FRONT of the body (zPosition 1 > body's 0) so the tail
            // root visually covers the body's thin caudal peduncle end.
            tail.zPosition = 1
            rootNode.addChild(tail)
            tailSprite = tail
        } else {
            tailSprite = nil
        }
    }

    // MARK: - Per-Frame Update

    func update(spinePositions: [CGPoint]) {
        guard spinePositions.count >= 2 else { return }

        // Sanitize spine before rendering to suppress physics outliers.
        let renderSpine  = sanitizeSpinePositions(spinePositions)
        let renderAngles = computeAngles(from: renderSpine)

        // Compute and stabilise the bounding frame for the body sprite.
        let targetFrame = computeSpriteFrame(spinePositions: renderSpine)
        let frame       = stabilizeFrame(targetFrame)

        // --- Body ---
        rootNode.position = CGPoint(x: frame.midX, y: frame.midY)
        bodySprite.size   = frame.size
        bodySprite.position = .zero

        let warpGrid = meshDeformer.createWarpGrid(
            spinePositions: renderSpine,
            spineAngles:    renderAngles,
            spriteFrame:    frame,
            bodyWidth:      bodyWidth
        )
        bodySprite.warpGeometry = warpGrid

        // --- Tail fin ---
        // Attach at the second-to-last spine particle so the tail sprite's root
        // overlaps the body's thin caudal area, hiding the needle-like peduncle.
        // (The tail is zPosition=1, so it renders in front of the body at that point.)
        if let tail = tailSprite, renderSpine.count >= 2 {
            // Use N-2 so the tail root sits one segment back from the spine tip.
            let attachIdx   = renderSpine.count - 2
            let attachPos   = renderSpine[attachIdx]
            let attachAngle = renderAngles[attachIdx]   // angle toward head

            // Convert world position → rootNode local space.
            tail.position = CGPoint(
                x: attachPos.x - frame.midX,
                y: attachPos.y - frame.midY
            )

            // Fan opens AWAY from the body (opposite of head direction).
            let rawAngle = attachAngle + .pi

            // Smooth tail rotation to avoid single-frame angle spikes from physics noise.
            let smoothed: CGFloat
            if let prev = smoothedTailAngle {
                var diff = rawAngle - prev
                while diff >  .pi { diff -= 2 * .pi }
                while diff < -.pi { diff += 2 * .pi }
                smoothed = prev + diff * 0.40
            } else {
                smoothed = rawAngle
            }
            smoothedTailAngle = smoothed
            tail.zRotation = smoothed
        }
    }

    // MARK: - Frame Helpers

    /// Compute a bounding frame encompassing all spine positions plus body-width padding.
    private func computeSpriteFrame(spinePositions: [CGPoint]) -> CGRect {
        guard !spinePositions.isEmpty else {
            return CGRect(x: 0, y: 0, width: bodyLength, height: bodyWidth)
        }

        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for pos in spinePositions {
            minX = min(minX, pos.x)
            maxX = max(maxX, pos.x)
            minY = min(minY, pos.y)
            maxY = max(maxY, pos.y)
        }

        let padding = bodyWidth * 0.7
        minX -= padding; maxX += padding
        minY -= padding; maxY += padding

        let width  = max(maxX - minX, bodyLength * 0.6)
        let height = max(maxY - minY, bodyWidth  * 1.5)
        let cx = (minX + maxX) / 2
        let cy = (minY + maxY) / 2

        return CGRect(x: cx - width / 2, y: cy - height / 2, width: width, height: height)
    }

    /// Clamp render-only segment lengths to suppress occasional extreme outliers.
    private func sanitizeSpinePositions(_ positions: [CGPoint]) -> [CGPoint] {
        guard positions.count >= 2 else { return positions }

        let maxSegLength = FishConfig.spineSegmentLength * 1.8
        var sanitized: [CGPoint] = [positions[0]]

        for i in 1..<positions.count {
            let prev = sanitized[i - 1]
            var curr = positions[i]
            if !curr.x.isFinite || !curr.y.isFinite { curr = prev }

            let dx = curr.x - prev.x
            let dy = curr.y - prev.y
            let dist = sqrt(dx * dx + dy * dy)

            if dist > maxSegLength, dist > 0.001 {
                let scale = maxSegLength / dist
                curr = CGPoint(x: prev.x + dx * scale, y: prev.y + dy * scale)
            }
            sanitized.append(curr)
        }
        return sanitized
    }

    /// Recompute segment angles from render spine.
    /// Returns the angle at each particle pointing FROM that particle TOWARD the head
    /// (i.e. atan2(p[i] - p[i+1])).  Adding π gives the tail-outward direction.
    private func computeAngles(from positions: [CGPoint]) -> [CGFloat] {
        guard positions.count >= 2 else { return positions.isEmpty ? [] : [0] }

        var angles: [CGFloat] = []
        angles.reserveCapacity(positions.count)
        for i in 0..<(positions.count - 1) {
            let dx = positions[i].x - positions[i + 1].x
            let dy = positions[i].y - positions[i + 1].y
            angles.append(atan2(dy, dx))
        }
        angles.append(angles.last ?? 0)
        return angles
    }

    /// Exponential smoothing + per-frame step cap for frame center/size.
    private func stabilizeFrame(_ target: CGRect) -> CGRect {
        guard let previous = smoothedFrame else {
            smoothedFrame = target
            return target
        }

        let alpha: CGFloat = 0.22
        let maxCenterStep: CGFloat = FishConfig.spineSegmentLength * 0.8
        let maxSizeStep:   CGFloat = FishConfig.spineSegmentLength * 0.9

        let prevCenter   = CGPoint(x: previous.midX, y: previous.midY)
        let targetCenter = CGPoint(x: target.midX,   y: target.midY)
        let dx   = targetCenter.x - prevCenter.x
        let dy   = targetCenter.y - prevCenter.y
        let dist = sqrt(dx * dx + dy * dy)

        let limitedCenter: CGPoint
        if dist > maxCenterStep, dist > 0.001 {
            let scale = maxCenterStep / dist
            limitedCenter = CGPoint(x: prevCenter.x + dx * scale, y: prevCenter.y + dy * scale)
        } else {
            limitedCenter = targetCenter
        }

        let newCenter = CGPoint(
            x: prevCenter.x + (limitedCenter.x - prevCenter.x) * alpha,
            y: prevCenter.y + (limitedCenter.y - prevCenter.y) * alpha
        )

        let limitedWidth = max(
            bodyLength * 0.6,
            min(previous.width  + maxSizeStep, max(previous.width  - maxSizeStep, target.width))
        )
        let limitedHeight = max(
            bodyWidth  * 1.5,
            min(previous.height + maxSizeStep, max(previous.height - maxSizeStep, target.height))
        )
        let newWidth  = previous.width  + (limitedWidth  - previous.width)  * alpha
        let newHeight = previous.height + (limitedHeight - previous.height) * alpha

        let stabilized = CGRect(
            x: newCenter.x - newWidth  / 2,
            y: newCenter.y - newHeight / 2,
            width:  newWidth,
            height: newHeight
        )
        smoothedFrame = stabilized
        return stabilized
    }
}
