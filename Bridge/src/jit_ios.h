// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

#pragma once

namespace JitIOS {

/// True when this process may execute code it generated itself. On a device that means a
/// debugger (StikDebug, SideStore, Xcode) attached and the kernel flagged us CS_DEBUGGED, and
/// that iOS still lets a written page be flipped back to executable.
///
/// TODO(phase 2): iOS 27 refuses that even with a debugger, on A13 devices too: written pages
/// lose execute, and an RX alias of an RW mapping fails code signing. The debugger has to
/// allocate the RX region itself (as StikDebug's iOS 26 script does), and dynarmic and the
/// shader JIT must write through an RW alias of it instead of oaknut::CodeBlock.
bool IsAvailable();

} // namespace JitIOS
