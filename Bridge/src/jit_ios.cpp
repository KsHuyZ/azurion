// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

#include <TargetConditionals.h>
#include <mach/mach.h>
#include <sys/mman.h>
#include <unistd.h>
#include "common/common_types.h"
#include "common/logging/log.h"
#include "jit_ios.h"

#if !TARGET_OS_SIMULATOR
// Not in the public iOS SDK headers, but exported by libsystem.
extern "C" int csops(pid_t pid, unsigned int ops, void* useraddr, size_t usersize);
#endif

namespace JitIOS {

namespace {
constexpr unsigned int CS_OPS_STATUS = 0;
constexpr int CS_DEBUGGED = 0x10000000;

#if !TARGET_OS_SIMULATOR
vm_prot_t CurrentProtection(void* address) {
    vm_address_t region = reinterpret_cast<vm_address_t>(address);
    vm_size_t size = 0;
    vm_region_basic_info_data_64_t info{};
    mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object = MACH_PORT_NULL;
    if (vm_region_64(mach_task_self(), &region, &size, VM_REGION_BASIC_INFO_64,
                     reinterpret_cast<vm_region_info_t>(&info), &count, &object) != KERN_SUCCESS) {
        return VM_PROT_NONE;
    }
    return info.protection;
}

/// Replays what oaknut::CodeBlock does on iOS (map RX, flip to RW, write, flip back to RX) on one
/// page and checks the page is still executable. iOS 27 accepts the last mprotect yet silently
/// drops execute from a page that was written, even with a debugger attached; jumping into it
/// then kills the process. Only page protections are inspected, nothing is executed.
bool CanExecuteWrittenPages() {
    const size_t size = getpagesize();
    void* page = mmap(nullptr, size, PROT_READ | PROT_EXEC, MAP_ANON | MAP_PRIVATE, -1, 0);
    if (page == MAP_FAILED) {
        return false;
    }

    bool executable = false;
    if (mprotect(page, size, PROT_READ | PROT_WRITE) == 0) {
        *static_cast<volatile u32*>(page) = 0xD65F03C0; // ret
        executable = mprotect(page, size, PROT_READ | PROT_EXEC) == 0 &&
                     (CurrentProtection(page) & VM_PROT_EXECUTE) != 0;
    }
    munmap(page, size);
    return executable;
}
#endif

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
    if ((flags & CS_DEBUGGED) == 0) {
        return false;
    }
    if (!CanExecuteWrittenPages()) {
        LOG_WARNING(Frontend, "Debugger attached, but this iOS version does not let written "
                              "pages become executable");
        return false;
    }
    return true;
#endif
}

} // namespace JitIOS
