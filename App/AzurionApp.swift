// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

import AzurionCore
import SwiftUI

@main
struct AzurionApp: App {
    @State private var library = GameLibrary()

    init() {
        AppDirectories.createIfNeeded()
        Emulator.shared.configure(withUserDirectory: AppDirectories.coreData)
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(library)
        }
    }
}
