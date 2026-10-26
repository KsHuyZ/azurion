// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

import AzurionCore
import SwiftUI

/// On-screen controls, laid out for portrait where the core stacks both screens at the top.
/// Empty space is not hit-testable, so touches there reach the 3DS touch screen underneath.
/// TODO(phase 3): landscape layout, user-editable layouts, physical controllers (GameController).
struct VirtualGamepad: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

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

            HStack(spacing: 24) {
                GamepadButton(.select, title: "SELECT", shape: .small)
                GamepadButton(.start, title: "START", shape: .small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
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

    @State private var isPressed = false

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
                    .onChanged { _ in
                        guard !isPressed else { return }
                        isPressed = true
                        Emulator.shared.press(button)
                    }
                    .onEnded { _ in
                        isPressed = false
                        Emulator.shared.release(button)
                    }
            )
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

    @State private var knobOffset: CGSize = .zero

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
                .onChanged { value in
                    var dx = value.location.x - radius
                    var dy = value.location.y - radius
                    let distance = (dx * dx + dy * dy).squareRoot()
                    if distance > radius {
                        dx *= radius / distance
                        dy *= radius / distance
                    }
                    knobOffset = CGSize(width: dx, height: dy)
                    // Screen y grows downwards, the 3DS circle pad's y grows upwards.
                    Emulator.shared.setStick(stick, x: Float(dx / radius), y: Float(-dy / radius))
                }
                .onEnded { _ in
                    knobOffset = .zero
                    Emulator.shared.setStick(stick, x: 0, y: 0)
                }
        )
    }
}
