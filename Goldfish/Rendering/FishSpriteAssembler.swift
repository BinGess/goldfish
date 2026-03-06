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

    func update(spinePositions: [CGPoint], spineAngles: [CGFloat]) {
        guard spinePositions.count >= 2 else { return }

        // Compute bounding frame of the spine with padding for body width
        let frame = computeSpriteFrame(spinePositions: spinePositions)

        // Position rootNode at center of the bounding frame
        rootNode.position = CGPoint(x: frame.midX, y: frame.midY)

        // Resize body sprite to cover the bounding frame
        bodySprite.size = frame.size
        bodySprite.position = .zero

        // Create and apply the warp grid
        let warpGrid = meshDeformer.createWarpGrid(
            spinePositions: spinePositions,
            spineAngles: spineAngles,
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
}
