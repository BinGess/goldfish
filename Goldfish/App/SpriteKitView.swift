import SwiftUI
import SpriteKit

struct SpriteKitView: UIViewRepresentable {
    @ObservedObject var tuningStore: MotionTuningStore

    final class Coordinator {
        weak var scene: AquariumScene?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        skView.showsFPS = true
        skView.showsNodeCount = true

        let scene = AquariumScene()
        scene.scaleMode = .resizeFill
        scene.setMotionTuning(tuningStore.currentTuning)
        skView.presentScene(scene)
        context.coordinator.scene = scene

        return skView
    }

    func updateUIView(_ uiView: SKView, context: Context) {
        context.coordinator.scene?.setMotionTuning(tuningStore.currentTuning)
    }
}
