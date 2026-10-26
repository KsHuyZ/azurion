// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

import SwiftUI

struct EmulationScreen: View {
    let game: Game

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = EmulationModel()
    /// Whether the game was running when the app left the foreground.
    @State private var resumeOnActive = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            EmulatorSurface { layer, size in
                model.boot(game, layer: layer, drawableSize: size)
            }
            .ignoresSafeArea()

            VirtualGamepad()
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
