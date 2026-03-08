import SpriteKit

/// Assembles the fish from rigid segments instead of warping one large body texture.
/// This keeps the head stable during turns and lets the body bend as multiple bones.
final class FishSpriteAssembler {

    private struct BodySegmentSpec {
        let name: String
        let assetName: String
        let cropStart: CGFloat
        let cropEnd: CGFloat
        let spanStart: CGFloat
        let spanEnd: CGFloat
        let rotationT: CGFloat
        let heightScale: CGFloat
        let overlapRatio: CGFloat
        let centerOffsetRatio: CGFloat
        let anchorX: CGFloat
        let attachmentT: CGFloat?
        let attachmentInsetRatio: CGFloat
        let zPosition: CGFloat
        let smoothing: CGFloat
    }

    private struct BodySegmentNode {
        let spec: BodySegmentSpec
        let sprite: SKSpriteNode
    }

    private enum Layout {
        static let bodySegments: [BodySegmentSpec] = [
            BodySegmentSpec(
                name: "head",
                assetName: "fish_head",
                cropStart: 0.71,
                cropEnd: 1.00,
                spanStart: 0.00,
                spanEnd: 0.19,
                rotationT: 0.03,
                heightScale: 0.90,
                overlapRatio: 0.08,
                centerOffsetRatio: -0.01,
                anchorX: 0.0,
                attachmentT: 0.19,
                attachmentInsetRatio: -0.03,
                zPosition: 7,
                smoothing: 0.14
            ),
            BodySegmentSpec(
                name: "shoulder",
                assetName: "fish_shoulder",
                cropStart: 0.50,
                cropEnd: 0.78,
                spanStart: 0.09,
                spanEnd: 0.40,
                rotationT: 0.24,
                heightScale: 1.08,
                overlapRatio: 0.26,
                centerOffsetRatio: 0.03,
                anchorX: 0.5,
                attachmentT: nil,
                attachmentInsetRatio: 0,
                zPosition: 5,
                smoothing: 0.20
            ),
            BodySegmentSpec(
                name: "midBody",
                assetName: "fish_mid",
                cropStart: 0.31,
                cropEnd: 0.56,
                spanStart: 0.38,
                spanEnd: 0.62,
                rotationT: 0.50,
                heightScale: 1.04,
                overlapRatio: 0.18,
                centerOffsetRatio: 0.02,
                anchorX: 0.5,
                attachmentT: nil,
                attachmentInsetRatio: 0,
                zPosition: 3,
                smoothing: 0.24
            ),
            BodySegmentSpec(
                name: "rearBody",
                assetName: "fish_rear",
                cropStart: 0.16,
                cropEnd: 0.37,
                spanStart: 0.58,
                spanEnd: 0.78,
                rotationT: 0.69,
                heightScale: 0.60,
                overlapRatio: 0.10,
                centerOffsetRatio: 0.00,
                anchorX: 0.5,
                attachmentT: nil,
                attachmentInsetRatio: 0,
                zPosition: 2,
                smoothing: 0.28
            ),
            BodySegmentSpec(
                name: "peduncle",
                assetName: "fish_peduncle",
                cropStart: 0.00,
                cropEnd: 0.23,
                spanStart: 0.78,
                spanEnd: 0.88,
                rotationT: 0.86,
                heightScale: 0.26,
                overlapRatio: 0.08,
                centerOffsetRatio: 0.00,
                anchorX: 0.5,
                attachmentT: nil,
                attachmentInsetRatio: 0,
                zPosition: 1,
                smoothing: 0.30
            )
        ]

        static let tailWidthScale: CGFloat = 0.64
        static let tailHeightScale: CGFloat = 1.18
        static let tailOverlapRatio: CGFloat = 0.24
        static let tailSmoothing: CGFloat = 0.24
        static let tailZPosition: CGFloat = 2.5
    }

    // MARK: - Sprite Nodes

    let rootNode: SKNode

    private let bodySegments: [BodySegmentNode]
    private let tailSprite: SKSpriteNode?

    // MARK: - Dimensions

    let bodyWidth: CGFloat
    let bodyLength: CGFloat

    // MARK: - State

    private var smoothedSegmentAngles: [CGFloat?]
    private var smoothedTailAngle: CGFloat?

    // MARK: - Init

    init(
        bodyTexture: SKTexture? = nil,
        bodySegmentTextures: [String: SKTexture] = [:],
        tailTexture: SKTexture? = nil,
        bodyLength: CGFloat = 240,
        bodyWidth: CGFloat = 90
    ) {
        self.bodyLength = bodyLength
        self.bodyWidth = bodyWidth

        rootNode = SKNode()
        rootNode.name = "fishRoot"
        rootNode.zPosition = 100

        var segmentNodes: [BodySegmentNode] = []
        segmentNodes.reserveCapacity(Layout.bodySegments.count)

        for spec in Layout.bodySegments {
            let texture: SKTexture
            if let segmentTexture = bodySegmentTextures[spec.assetName] {
                texture = segmentTexture
            } else if let bodyTexture {
                texture = Self.croppedTexture(
                    from: bodyTexture,
                    start: spec.cropStart,
                    end: spec.cropEnd
                )
            } else {
                preconditionFailure("Missing texture for segment \(spec.assetName)")
            }
            let sprite = SKSpriteNode(texture: texture)
            sprite.name = spec.name
            sprite.anchorPoint = CGPoint(x: spec.anchorX, y: 0.5)
            sprite.zPosition = spec.zPosition
            rootNode.addChild(sprite)
            segmentNodes.append(BodySegmentNode(spec: spec, sprite: sprite))
        }

        bodySegments = segmentNodes
        smoothedSegmentAngles = Array(repeating: nil, count: segmentNodes.count)

        if let tailTexture {
            let tail = SKSpriteNode(texture: tailTexture)
            tail.name = "tail"
            tail.anchorPoint = CGPoint(x: 1.0, y: 0.5)
            tail.zPosition = Layout.tailZPosition
            rootNode.addChild(tail)
            tailSprite = tail
        } else {
            tailSprite = nil
        }
    }

    // MARK: - Per-Frame Update

    func update(spinePositions: [CGPoint]) {
        guard spinePositions.count >= 2 else { return }

        let renderSpine = sanitizeSpinePositions(spinePositions)
        let renderAngles = computeAngles(from: renderSpine)

        rootNode.position = .zero

        for index in bodySegments.indices {
            let segment = bodySegments[index]
            let spec = segment.spec

            let rawAngle = interpolateAngle(at: spec.rotationT, angles: renderAngles)
            let smoothedAngle: CGFloat
            if let previous = smoothedSegmentAngles[index] {
                smoothedAngle = smoothAngle(
                    rawAngle,
                    previous: previous,
                    factor: spec.smoothing
                )
            } else {
                smoothedAngle = rawAngle
            }
            smoothedSegmentAngles[index] = smoothedAngle

            let segmentLength = arcLength(
                from: spec.spanStart,
                to: spec.spanEnd,
                positions: renderSpine
            )
            let width = max(
                bodyLength * 0.05,
                segmentLength + bodyWidth * spec.overlapRatio
            )
            let height = max(bodyWidth * 0.22, bodyWidth * spec.heightScale)
            let bodyDirection = CGVector(dx: cos(smoothedAngle), dy: sin(smoothedAngle))
            let position: CGPoint
            if let attachmentT = spec.attachmentT {
                let attachment = interpolateSpine(at: attachmentT, positions: renderSpine)
                let inset = bodyWidth * spec.attachmentInsetRatio
                position = CGPoint(
                    x: attachment.x + bodyDirection.dx * inset,
                    y: attachment.y + bodyDirection.dy * inset
                )
            } else {
                let centerT = (spec.spanStart + spec.spanEnd) * 0.5
                let center = interpolateSpine(at: centerT, positions: renderSpine)
                let centerOffset = segmentLength * spec.centerOffsetRatio
                position = CGPoint(
                    x: center.x + bodyDirection.dx * centerOffset,
                    y: center.y + bodyDirection.dy * centerOffset
                )
            }

            segment.sprite.position = position
            segment.sprite.zRotation = smoothedAngle
            segment.sprite.size = CGSize(width: width, height: height)
        }

        updateTail(renderSpine: renderSpine, renderAngles: renderAngles)
    }

    // MARK: - Tail

    private func updateTail(renderSpine: [CGPoint], renderAngles: [CGFloat]) {
        guard let tailSprite else { return }

        guard let peduncleSpec = bodySegments.last?.spec else { return }

        let attachPosition = interpolateSpine(at: peduncleSpec.spanEnd, positions: renderSpine)
        let rawAngle = smoothedSegmentAngles.last.flatMap { $0 }
            ?? interpolateAngle(at: peduncleSpec.rotationT, angles: renderAngles)
        let smoothedAngle: CGFloat

        if let previous = smoothedTailAngle {
            smoothedAngle = smoothAngle(
                rawAngle,
                previous: previous,
                factor: Layout.tailSmoothing
            )
        } else {
            smoothedAngle = rawAngle
        }
        smoothedTailAngle = smoothedAngle

        let bodyDirection = CGVector(dx: cos(smoothedAngle), dy: sin(smoothedAngle))
        let overlap = bodyWidth * Layout.tailOverlapRatio
        tailSprite.position = CGPoint(
            x: attachPosition.x + bodyDirection.dx * overlap,
            y: attachPosition.y + bodyDirection.dy * overlap
        )
        tailSprite.zRotation = smoothedAngle
        tailSprite.size = CGSize(
            width: bodyWidth * Layout.tailWidthScale,
            height: bodyWidth * Layout.tailHeightScale
        )
    }

    // MARK: - Geometry Helpers

    /// Clamp render-only segment lengths to suppress occasional physics outliers.
    private func sanitizeSpinePositions(_ positions: [CGPoint]) -> [CGPoint] {
        guard positions.count >= 2 else { return positions }

        let maxSegmentLength = FishConfig.spineSegmentLength * 1.8
        var sanitized: [CGPoint] = [positions[0]]

        for index in 1..<positions.count {
            let previous = sanitized[index - 1]
            var current = positions[index]
            if !current.x.isFinite || !current.y.isFinite {
                current = previous
            }

            let dx = current.x - previous.x
            let dy = current.y - previous.y
            let distance = sqrt(dx * dx + dy * dy)

            if distance > maxSegmentLength, distance > 0.001 {
                let scale = maxSegmentLength / distance
                current = CGPoint(
                    x: previous.x + dx * scale,
                    y: previous.y + dy * scale
                )
            }
            sanitized.append(current)
        }

        return sanitized
    }

    /// Angles point from the sampled location back toward the head.
    private func computeAngles(from positions: [CGPoint]) -> [CGFloat] {
        guard positions.count >= 2 else { return positions.isEmpty ? [] : [0] }

        var angles: [CGFloat] = []
        angles.reserveCapacity(positions.count)

        for index in 0..<(positions.count - 1) {
            let dx = positions[index].x - positions[index + 1].x
            let dy = positions[index].y - positions[index + 1].y
            angles.append(atan2(dy, dx))
        }
        angles.append(angles.last ?? 0)
        return angles
    }

    private func interpolateSpine(at t: CGFloat, positions: [CGPoint]) -> CGPoint {
        guard positions.count >= 2 else { return positions.first ?? .zero }

        let clampedT = max(0, min(1, t))
        let maxIndex = CGFloat(positions.count - 1)
        let rawIndex = clampedT * maxIndex
        let index0 = min(Int(rawIndex), positions.count - 1)
        let index1 = min(index0 + 1, positions.count - 1)
        let fraction = rawIndex - CGFloat(index0)

        let p0 = positions[index0]
        let p1 = positions[index1]
        return CGPoint(
            x: p0.x + (p1.x - p0.x) * fraction,
            y: p0.y + (p1.y - p0.y) * fraction
        )
    }

    private func interpolateAngle(at t: CGFloat, angles: [CGFloat]) -> CGFloat {
        guard angles.count >= 2 else { return angles.first ?? 0 }

        let clampedT = max(0, min(1, t))
        let maxIndex = CGFloat(angles.count - 1)
        let rawIndex = clampedT * maxIndex
        let index0 = min(Int(rawIndex), angles.count - 1)
        let index1 = min(index0 + 1, angles.count - 1)
        let fraction = rawIndex - CGFloat(index0)

        let a0 = angles[index0]
        let a1 = angles[index1]
        var diff = a1 - a0
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        return a0 + diff * fraction
    }

    private func arcLength(from startT: CGFloat, to endT: CGFloat, positions: [CGPoint]) -> CGFloat {
        let sampleCount = 5
        let start = max(0, min(1, startT))
        let end = max(0, min(1, endT))
        guard end > start else { return 0 }

        var previous = interpolateSpine(at: start, positions: positions)
        var total: CGFloat = 0

        for sample in 1...sampleCount {
            let t = start + (end - start) * CGFloat(sample) / CGFloat(sampleCount)
            let current = interpolateSpine(at: t, positions: positions)
            let dx = current.x - previous.x
            let dy = current.y - previous.y
            total += sqrt(dx * dx + dy * dy)
            previous = current
        }

        return total
    }

    private func smoothAngle(_ angle: CGFloat, previous: CGFloat, factor: CGFloat) -> CGFloat {
        var delta = angle - previous
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return previous + delta * max(0, min(1, factor))
    }

    private static func croppedTexture(from bodyTexture: SKTexture, start: CGFloat, end: CGFloat) -> SKTexture {
        let rect = CGRect(
            x: max(0, min(1, start)),
            y: 0,
            width: max(0.01, min(1, end - start)),
            height: 1
        )
        return SKTexture(rect: rect, in: bodyTexture)
    }
}
