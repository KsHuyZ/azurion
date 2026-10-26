// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

import Foundation

/// Everything lives under Documents, which the Files app shows (UIFileSharingEnabled), so users
/// can drop in games and pull out saves (e.g. for PKHeX) without extra UI.
enum AppDirectories {
    static let games = URL.documentsDirectory.appending(path: "Games", directoryHint: .isDirectory)

    /// Azahar's user directory: saves (sdmc/nand), config, system files, shader cache, logs.
    static let coreData = URL.documentsDirectory.appending(path: "Data", directoryHint: .isDirectory)

    static func createIfNeeded() {
        for directory in [games, coreData] {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
