# Azurion

A Nintendo 3DS emulator for iOS, built on the [Azahar](https://github.com/azahar-emu/azahar) core.
Azurion focuses on delivering a great experience for the Pokémon series (X/Y, ORAS, Sun/Moon, USUM) on iPhone.

> **Legal notice.** Azurion does not include or download any games, BIOS, firmware, or AES keys.
> It only runs **decrypted** dumps made by users from their own 3DS consoles.
> The core is built with `ENABLE_BUILTIN_KEYBLOB=OFF`.
> No Pokémon or Nintendo names, logos, or imagery are used in the app or on any store listing.

## Architecture

```
SwiftUI app (App/)                      game library, gameplay screen, virtual gamepad
        │  import AzurionCore
AzurionCore.framework (Bridge/)         Objective-C API; all C++ lives here
        │
Azahar core (external/azahar, submodule)
  ├─ CPU   dynarmic JIT (requires StikDebug), interpreter fallback
  ├─ GPU   Vulkan → MoltenVK → Metal, rendering into a CAMetalLayer
  └─ Audio OpenAL → CoreAudio
```

- **App/**: Pure Swift with no C++ dependencies. Talks to the core through `Emulator.shared`.
- **Bridge/**: Objective-C++. Modeled after Azahar's Android frontend
  (`src/android/app/src/main/jni`). Built inside Azahar's CMake tree.
- **patches/azahar/**: Minimal patches to the core, applied automatically by `bootstrap.sh`.
  - `0001`: Hooks the `Bridge/` directory into Azahar's CMake build.
  - `0002`: Lets the iOS frontend provide MoltenVK (statically linked) to the Vulkan renderer.
  - `0003`: Adds iOS (UIKit) support to `AppleUtils`.

## Requirements

- An Apple Silicon Mac with **Xcode 26** (requires macOS 15.6 or later) and the iOS SDK.
- `brew install cmake ninja xcodegen`
- About 20 GB of free disk space for dependencies and build output.
- An iPhone running iOS 17 or later. Full-speed emulation requires JIT, enabled via
  [StikDebug](https://stikdebug.org/). JIT is always available in the Simulator.

## Building

```sh
scripts/bootstrap.sh          # submodules + patches + generate Azurion.xcodeproj (run once)
scripts/build-core.sh         # build the core → build/AzurionCore.xcframework (slow on first run)
open Azurion.xcodeproj        # select your Team under Signing, then run the Azurion target
```

- Device only: `scripts/build-core.sh device`. Simulator only: `scripts/build-core.sh simulator`.
- After changing anything in `Bridge/` or `external/azahar`, re-run `build-core.sh` (incremental build).
- After editing `project.yml`, re-run `xcodegen generate`.

Games can be imported in the app (the **+** button) or copied into *Files › Azurion › Games*.
Saves, configuration, and logs are stored in *Files › Azurion › Data*.

## Working with upstream Azahar

- The submodule points to the upstream repository. If deeper core changes are needed, fork
  `azahar-emu/azahar` and run `git submodule set-url external/azahar <fork>`.
- Keep core patches as small as possible so rebasing onto upstream stays easy.
- Azahar has an [AI policy](external/azahar/AI-POLICY.md): **do not submit AI-generated code upstream**
  (except for snippets of roughly 5 lines or fewer, clearly disclosed). Patches intended for upstream
  contribution must be written by a human.
- Azahar is licensed under GPLv3, so Azurion is also GPLv3 and its source code must remain public,
  including for any release with paid features.

## Roadmap

| Phase | Goal | Status |
|---|---|---|
| 0 | Project scaffolding: bridge, SwiftUI app, build scripts | ✅ Code complete, not yet test-built |
| 1 | Boot Pokémon X on iPhone: video, audio, touch input, virtual gamepad | ⏳ |
| 2 | JIT: StikDebug guide, iOS 26 TXM support, shader cache progress, memory entitlements | |
| 3 | Beta: landscape layout, controller support (GameController), save states, save manager (`.sav` for PKHeX), 3DS software keyboard, cheats, per-game settings, fast-forward | |
| 4 | Release: SideStore/AltStore, AltStore PAL, App Store submission attempt, StoreKit for the Pro version | |
| 5 | Trading and battling between two iPhones via multiplayer rooms | |

## License

GPLv3 or later; see [LICENSE](LICENSE). Azahar: GPLv2+/GPLv3+; see `external/azahar/LICENSE.txt`.
