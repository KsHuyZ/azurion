// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

#include <TargetConditionals.h>
#include <unistd.h>
#include "jit_ios.h"

#if !TARGET_OS_SIMULATOR
// Not in the public iOS SDK headers, but exported by libsystem.
extern "C" int csops(pid_t pid, unsigned int ops, void* useraddr, size_t usersize);
#endif

namespace JitIOS {

namespace {
constexpr unsigned int CS_OPS_STATUS = 0;
constexpr int CS_DEBUGGED = 0x10000000;
} // Anonymous namespace

bool IsAvailable() {
#if TARGET_OS_SIMULATOR
    // The simulator runs as a regular macOS process, where MAP_JIT just works.
    return true;
#else
    int flags = 0;
    if (csops(getpid(), CS_OPS_STATUS, &flags, sizeof(flags)) != 0) {
        return false;
    }
    return (flags & CS_DEBUGGED) != 0;
#endif
}

} // namespace JitIOS
