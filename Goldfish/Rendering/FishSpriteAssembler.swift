import SpriteKit

/// Assembles and manages the layered fish sprite with warp-grid deformation.
/// The sprite uses a fixed large size and is repositioned each frame to
/// cover the spine bounding box. The warp grid bends the texture to follow
/// the spine curve.
final class FishSpriteAssembler {

    // MARK: - Sprite Nodes

    /// The root node containing all fish visual elements.
    let rootNode: SKNode

    /// The body sprite with warp geometry applied.
    private let bodySprite: SKSpriteNode

    /// The mesh deformer that maps spine → warp grid.
    private let meshDeformer: MeshDeformer

    /// Visual body width for warp calculations (points).
    let bodyWidth: CGFloat

    /// Visual body length for sprite sizing.
    let bodyLength: CGFloat

    /// Smoothed render frame to suppress occasional mesh spikes.
    private var smoothedFrame: CGRect?

    // MARK: - Init

    init(texture: SKTexture, bodyLength: CGFloat = 240, bodyWidth: CGFloat = 90) {
        self.bodyLength = bodyLength
        self.bodyWidth = bodyWidth
        self.meshDeformer = MeshDeformer()

        // Root node positioned at world origin; sprite is child
        rootNode = SKNode()
        rootNode.name = "fishRoot"
        rootNode.zPosition = 100

        // Body sprite: fixed size, centered at rootNode
        bodySprite = SKSpriteNode(texture: texture)
        bodySprite.size = CGSize(width: bodyLength * 1.5, height: bodyLength * 1.5)
        bodySprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // Initialize with identity warp grid
        let initialGrid = SKWarpGeometryGrid(
            columns: meshDeformer.columns,
            rows: meshDeformer.rows
        )
        bodySprite.warpGeometry = initialGrid

        rootNode.addChild(bodySprite)
    }

    // MARK: - Per-Frame Update

    func update(spinePositions: [CGPoint]) {
        guard spinePositions.count >= 2 else { return }

        // Rendering should be robust to transient physics outliers.
        // We sanitize the render chain only (without mutating physics state).
        let renderSpine = sanitizeSpinePositions(spinePositions)
        let renderAngles = computeAngles(from: renderSpine)

        // Compute and smooth the render frame to avoid visual "teleport" snaps.
        let targetFrame = computeSpriteFrame(spinePositions: renderSpine)
        let frame = stabilizeFrame(targetFrame)

        // Position rootNode at center of the bounding frame
        rootNode.position = CGPoint(x: frame.midX, y: frame.midY)

        // Resize body sprite to cover the bounding frame
        bodySprite.size = frame.size
        bodySprite.position = .zero

        // Create and apply the warp grid
        let warpGrid = meshDeformer.createWarpGrid(
            spinePositions: renderSpine,
            spineAngles: renderAngles,
            spriteFrame: frame,
            bodyWidth: bodyWidth
        )
        bodySprite.warpGeometry = warpGrid

    }

    // MARK: - Helpers

    /// Compute a bounding frame that encompasses all spine positions plus padding for body width.
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

        // Padding: body width on all sides to accommodate lateral deformation
        let padding = bodyWidth * 0.7
        minX -= padding
        maxX += padding
        minY -= padding
        maxY += padding

        // Ensure minimum dimensions
        let width = max(maxX - minX, bodyLength * 0.6)
        let height = max(maxY - minY, bodyWidth * 1.5)

        // Center the minimum size if needed
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
            if !curr.x.isFinite || !curr.y.isFinite {
                curr = prev
            }

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

    /// Recompute segment angles from render spine so warp orientation matches sanitized points.
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
        let maxSizeStep: CGFloat = FishConfig.spineSegmentLength * 0.9

        let prevCenter = CGPoint(x: previous.midX, y: previous.midY)
        let targetCenter = CGPoint(x: target.midX, y: target.midY)
        let dx = targetCenter.x - prevCenter.x
        let dy = targetCenter.y - prevCenter.y
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
            min(previous.width + maxSizeStep, max(previous.width - maxSizeStep, target.width))
        )
        let limitedHeight = max(
            bodyWidth * 1.5,
            min(previous.height + maxSizeStep, max(previous.height - maxSizeStep, target.height))
        )
        let newWidth = previous.width + (limitedWidth - previous.width) * alpha
        let newHeight = previous.height + (limitedHeight - previous.height) * alpha

        let stabilized = CGRect(
            x: newCenter.x - newWidth / 2,
            y: newCenter.y - newHeight / 2,
            width: newWidth,
            height: newHeight
        )
        smoothedFrame = stabilized
        return stabilized
    }
}
