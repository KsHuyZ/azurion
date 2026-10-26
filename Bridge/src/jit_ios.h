// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

#pragma once

namespace JitIOS {

/// True when this process may execute code it generated itself. On a device that means a
/// debugger (StikDebug, SideStore, Xcode) attached and the kernel flagged us CS_DEBUGGED.
///
/// TODO(phase 2): iOS 26 devices with TXM additionally need the debugger to prepare the JIT
/// region before the first write; the dynarmic code buffer must be allocated up front for that.
bool IsAvailable();

} // namespace JitIOS
