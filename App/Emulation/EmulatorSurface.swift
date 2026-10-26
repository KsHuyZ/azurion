// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

import AzurionCore
import SwiftUI
import UIKit

/// Hosts the CAMetalLayer the core renders into (Vulkan → MoltenVK → Metal) and forwards touches
/// to the 3DS touch screen. The core maps pixel positions onto the bottom screen itself.
final class EmulatorSurfaceView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }

    var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    /// Called once, when the view first has a real size, with the drawable size in pixels.
    var onReady: ((CAMetalLayer, CGSize) -> Void)?
    private var isReady = false

    override func layoutSubviews() {
        super.layoutSubviews()

        contentScaleFactor = traitCollection.displayScale
        let size = CGSize(width: bounds.width * contentScaleFactor,
                          height: bounds.height * contentScaleFactor)
        guard size.width > 0, size.height > 0 else { return }
        metalLayer.drawableSize = size

        if isReady {
            Emulator.shared.drawableSizeDidChange(size)
        } else {
            isReady = true
            onReady?(metalLayer, size)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        Emulator.shared.touchBegan(at: pixelLocation(of: touch))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        Emulator.shared.touchMoved(to: pixelLocation(of: touch))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        Emulator.shared.touchEnded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        Emulator.shared.touchEnded()
    }

    private func pixelLocation(of touch: UITouch) -> CGPoint {
        let point = touch.location(in: self)
        return CGPoint(x: point.x * contentScaleFactor, y: point.y * contentScaleFactor)
    }
}

struct EmulatorSurface: UIViewRepresentable {
    let onReady: (CAMetalLayer, CGSize) -> Void

    func makeUIView(context: Context) -> EmulatorSurfaceView {
        let view = EmulatorSurfaceView()
        view.backgroundColor = .black
        view.onReady = onReady
        return view
    }

    func updateUIView(_ uiView: EmulatorSurfaceView, context: Context) {}
}
