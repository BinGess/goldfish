import SwiftUI
import SpriteKit

struct SpriteKitView: UIViewRepresentable {

    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        skView.showsFPS = true
        skView.showsNodeCount = true

        let scene = AquariumScene()
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)

        return skView
    }

    func updateUIView(_ uiView: SKView, context: Context) {}
}
