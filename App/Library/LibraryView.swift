// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

import AzurionCore
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(GameLibrary.self) private var library
    @State private var isImporting = false
    @State private var importError: String?
    @State private var playing: Game?

    var body: some View {
        NavigationStack {
            List {
                if !Emulator.isJITAvailable {
                    Section {
                        JITBanner()
                    }
                }

                Section {
                    ForEach(library.games) { game in
                        Button(game.title) { playing = game }
                            .swipeActions {
                                Button("Delete", role: .destructive) {
                                    try? library.delete(game)
                                }
                            }
                    }
                } footer: {
                    if library.games.isEmpty {
                        Text("Import decrypted games you dumped from your own 3DS, or copy them into Azurion › Games in the Files app.")
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                Button("Import", systemImage: "plus") { isImporting = true }
            }
            .refreshable { library.refresh() }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.data],
                          allowsMultipleSelection: true) { result in
                do {
                    try library.importGames(from: result.get())
                } catch {
                    importError = error.localizedDescription
                }
            }
            .alert("Import failed", isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(importError ?? "")
            }
            .fullScreenCover(item: $playing) { game in
                EmulationScreen(game: game)
            }
        }
    }
}

private struct JITBanner: View {
    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("JIT is off").font(.headline)
                // TODO(phase 2): step-by-step StikDebug onboarding.
                Text("Games will run very slowly. Enable JIT with StikDebug, then relaunch Azurion.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "tortoise.fill").foregroundStyle(.orange)
        }
    }
}
