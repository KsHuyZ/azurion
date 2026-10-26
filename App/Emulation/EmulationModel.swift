// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

import AzurionCore
import Foundation
import Observation
import QuartzCore

@MainActor
@Observable
final class EmulationModel {
    private(set) var isPaused = false
    private(set) var performance = EmulatorPerformance()
    /// Set when the session ends. `message` is nil for a normal quit.
    private(set) var outcome: (reason: EmulatorExitReason, message: String?)?

    private var statsTimer: Timer?

    func boot(_ game: Game, layer: CAMetalLayer, drawableSize: CGSize) {
        Emulator.shared.boot(game: game.url, layer: layer, drawableSize: drawableSize) {
            [weak self] reason in
            self?.statsTimer?.invalidate()
            self?.outcome = (reason, reason.message)
        }

        statsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.performance = Emulator.shared.takePerformance()
            }
        }
    }

    func togglePause() {
        if isPaused {
            resume()
        } else {
            pause()
        }
    }

    func pause() {
        Emulator.shared.pause()
        isPaused = true
    }

    func resume() {
        Emulator.shared.resume()
        isPaused = false
    }

    func quit() {
        Emulator.shared.stop()
    }
}

extension EmulatorExitReason {
    var message: String? {
        switch self {
        case .stopped:
            nil
        case .encryptedGame:
            "This game is still encrypted. Azurion only runs decrypted dumps of games you own."
        case .invalidFormat:
            "This file is not a 3DS game Azurion can load."
        case .missingSystemFiles:
            "This game needs 3DS system files. Dump them from your own console."
        case .coreCrashed:
            "The emulated CPU crashed."
        case .otherError:
            "Something went wrong. See Data/log in the Files app for details."
        @unknown default:
            "Something went wrong."
        }
    }
}
