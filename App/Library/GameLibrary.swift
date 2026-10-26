// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

import Foundation
import Observation

struct Game: Identifiable, Hashable {
    let url: URL

    var id: URL { url }
    // TODO: read the real title and icon from the game's SMDH through the bridge.
    var title: String { url.deletingPathExtension().lastPathComponent }
}

/// The games in Documents/Games.
@Observable
final class GameLibrary {
    /// Formats Azahar can boot directly. CIA files must be installed first, so they are not listed.
    static let bootableExtensions: Set<String> = [
        "3ds", "cci", "cxi", "3dsx", "app", "elf", "axf", "zcci", "zcxi", "z3dsx",
    ]

    private(set) var games: [Game] = []

    init() {
        refresh()
    }

    func refresh() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: AppDirectories.games,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        games = urls
            .filter { Self.bootableExtensions.contains($0.pathExtension.lowercased()) }
            .map(Game.init(url:))
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Copies files picked in the document picker into Documents/Games.
    func importGames(from urls: [URL]) throws {
        for source in urls {
            let accessing = source.startAccessingSecurityScopedResource()
            defer {
                if accessing { source.stopAccessingSecurityScopedResource() }
            }

            let destination = AppDirectories.games.appending(path: source.lastPathComponent)
            if FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
        }
        refresh()
    }

    func delete(_ game: Game) throws {
        try FileManager.default.removeItem(at: game.url)
        refresh()
    }
}
