// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

import SwiftUI

struct EmulationScreen: View {
    let game: Game

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    /// Compact height means an iPhone in landscape.
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var model = EmulationModel()
    /// Whether the game was running when the app left the foreground.
    @State private var resumeOnActive = false

    /// Top screen (400x240) over bottom screen (320x240) at the same scale: the core's
    /// PortraitOriginal layout, set in AZEmulator. The surface keeps this shape in landscape too,
    /// so the core lays the screens out the same way in both orientations.
    private static let screensAspectRatio: CGFloat = 400.0 / 480.0

    var body: some View {
        let isLandscape = verticalSizeClass == .compact
        // AnyLayout keeps the surface's identity across rotation. An if/else would recreate it,
        // and with it the CAMetalLayer, which would boot the game a second time.
        let layout = isLandscape
            ? AnyLayout(HStackLayout(spacing: 0))
            : AnyLayout(VStackLayout(spacing: 0))

        ZStack {
            Color.black.ignoresSafeArea()

            // Inside the safe area, so the notch does not cover the top screen, and next to the
            // controls so they never cover the touch screen.
            layout {
                if isLandscape {
                    GamepadColumn(side: .left)
                }

                EmulatorSurface { layer, size in
                    model.boot(game, layer: layer, drawableSize: size)
                }
                .aspectRatio(Self.screensAspectRatio, contentMode: .fit)
                .layoutPriority(1)

                if isLandscape {
                    GamepadColumn(side: .right)
                } else {
                    VirtualGamepad()
                }
            }
        }
        .overlay(alignment: .topTrailing) { menu }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        // iOS terminates apps that submit GPU work in the background.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if resumeOnActive { model.resume() }
                resumeOnActive = false
            } else if !model.isPaused {
                resumeOnActive = true
                model.pause()
            }
        }
        .onChange(of: model.outcome?.reason) { _, reason in
            if reason != nil, model.outcome?.message == nil { dismiss() }
        }
        .alert("Emulation stopped", isPresented: Binding(
            get: { model.outcome?.message != nil },
            set: { _ in }
        )) {
            Button("OK") { dismiss() }
        } message: {
            Text(model.outcome?.message ?? "")
        }
    }

    private var menu: some View {
        HStack(spacing: 12) {
            Text(String(format: "%.0f FPS", model.performance.gameFPS))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))

            Menu {
                Button(model.isPaused ? "Resume" : "Pause",
                       systemImage: model.isPaused ? "play.fill" : "pause.fill") {
                    model.togglePause()
                }
                Button("Quit", systemImage: "xmark", role: .destructive) {
                    model.quit()
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding()
    }
}
