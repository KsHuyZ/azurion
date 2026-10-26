// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

import AzurionCore
import SwiftUI

/// On-screen controls for portrait, in the space below the 3DS screens. Scales down uniformly
/// when that space is shorter than the controls, e.g. on 5.8" iPhones like the iPhone 11 Pro.
/// TODO(phase 3): user-editable layouts, physical controllers (GameController).
struct VirtualGamepad: View {
    var body: some View {
        ScaledToFitHeight {
            VStack(spacing: 16) {
                HStack {
                    GamepadButton(.l, title: "L", shape: .wide)
                    Spacer()
                    GamepadButton(.r, title: "R", shape: .wide)
                }

                HStack(alignment: .bottom) {
                    VStack(spacing: 20) {
                        AnalogStick(stick: .circlePad)
                        DPad()
                    }
                    Spacer()
                    FaceButtons()
                }

                StartSelect()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
}

/// One side of the on-screen controls for landscape, either side of the 3DS screens.
struct GamepadColumn: View {
    enum Side {
        case left, right
    }

    let side: Side

    var body: some View {
        ScaledToFitHeight {
            VStack(spacing: 16) {
                switch side {
                case .left:
                    GamepadButton(.l, title: "L", shape: .wide)
                    AnalogStick(stick: .circlePad)
                    DPad()
                case .right:
                    GamepadButton(.r, title: "R", shape: .wide)
                    FaceButtons()
                    StartSelect()
                }
            }
            .padding(.bottom, 8)
        }
    }
}

/// Lays `content` out at full size, bottom-aligned, and scales it down uniformly when the space
/// offered is shorter than that.
private struct ScaledToFitHeight<Content: View>: View {
    @ViewBuilder let content: Content

    /// Height of the content at full size.
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let scale = contentHeight > 0 ? min(1, proxy.size.height / contentHeight) : 1

            // Laid out wider by 1/scale, so the content spans the full width once scaled down.
            content
                .frame(width: proxy.size.width / scale)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                .scaleEffect(scale, anchor: .bottom)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
    }
}

private struct StartSelect: View {
    var body: some View {
        HStack(spacing: 24) {
            GamepadButton(.select, title: "SELECT", shape: .small)
            GamepadButton(.start, title: "START", shape: .small)
        }
    }
}

private struct FaceButtons: View {
    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                GamepadButton(.x, title: "X")
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            }
            GridRow {
                GamepadButton(.y, title: "Y")
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                GamepadButton(.a, title: "A")
            }
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                GamepadButton(.b, title: "B")
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            }
        }
    }
}

private struct DPad: View {
    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                GamepadButton(.up, title: "▲", shape: .square)
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            }
            GridRow {
                GamepadButton(.left, title: "◀", shape: .square)
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                GamepadButton(.right, title: "▶", shape: .square)
            }
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                GamepadButton(.down, title: "▼", shape: .square)
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
            }
        }
    }
}

struct GamepadButton: View {
    enum Style {
        case round, square, wide, small

        var size: CGSize {
            switch self {
            case .round: CGSize(width: 52, height: 52)
            case .square: CGSize(width: 40, height: 40)
            case .wide: CGSize(width: 84, height: 36)
            case .small: CGSize(width: 72, height: 26)
            }
        }
    }

    let button: EmulatorButton
    let title: String
    var shape: Style = .round

    /// A gesture state, not @State: SwiftUI resets it when the touch is cancelled (system
    /// gestures, Notification Center, a call), where DragGesture.onEnded never fires and the
    /// button would stay held until the view is recreated.
    @GestureState private var isPressed = false

    init(_ button: EmulatorButton, title: String, shape: Style = .round) {
        self.button = button
        self.title = title
        self.shape = shape
    }

    var body: some View {
        Text(title)
            .font(.system(size: shape == .small ? 11 : 18, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: shape.size.width, height: shape.size.height)
            .background(background.fill(.white.opacity(isPressed ? 0.45 : 0.18)))
            .contentShape(background)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, pressed, _ in pressed = true }
            )
            .onChange(of: isPressed) { _, pressed in
                if pressed {
                    Emulator.shared.press(button)
                } else {
                    Emulator.shared.release(button)
                }
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isPressed) { _, pressed in pressed }
    }

    private var background: AnyShape {
        switch shape {
        case .round: AnyShape(Circle())
        case .square: AnyShape(RoundedRectangle(cornerRadius: 6))
        case .wide, .small: AnyShape(Capsule())
        }
    }
}

struct AnalogStick: View {
    let stick: EmulatorStick
    var diameter: CGFloat = 120

    /// A gesture state so the stick recentres when the touch is cancelled, as in GamepadButton.
    @GestureState private var knobOffset: CGSize = .zero

    var body: some View {
        let radius = diameter / 2

        ZStack {
            Circle().fill(.white.opacity(0.12))
            Circle()
                .fill(.white.opacity(0.35))
                .frame(width: diameter * 0.45, height: diameter * 0.45)
                .offset(knobOffset)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($knobOffset) { value, offset, _ in
                    var dx = value.location.x - radius
                    var dy = value.location.y - radius
                    let distance = (dx * dx + dy * dy).squareRoot()
                    if distance > radius {
                        dx *= radius / distance
                        dy *= radius / distance
                    }
                    offset = CGSize(width: dx, height: dy)
                }
        )
        .onChange(of: knobOffset) { _, offset in
            // Screen y grows downwards, the 3DS circle pad's y grows upwards.
            Emulator.shared.setStick(stick, x: Float(offset.width / radius),
                                     y: Float(-offset.height / radius))
        }
    }
}
