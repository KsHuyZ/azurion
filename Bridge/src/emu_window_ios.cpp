// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

#include <dlfcn.h>
#include "common/dynamic_library.h"
#include "common/logging/log.h"
#include "emu_window_ios.h"

extern "C" void* AzurionMoltenVKAnchor();

namespace {

class GraphicsContext_iOS final : public Frontend::GraphicsContext {
public:
    explicit GraphicsContext_iOS(std::shared_ptr<Common::DynamicLibrary> driver_library_)
        : driver_library{std::move(driver_library_)} {}

    std::shared_ptr<Common::DynamicLibrary> GetDriverLibrary() override {
        return driver_library;
    }

private:
    std::shared_ptr<Common::DynamicLibrary> driver_library;
};

/// MoltenVK is linked statically into AzurionCore.framework, so the Vulkan entry points live in
/// our own image instead of a libvulkan.dylib the core could dlopen by name.
std::shared_ptr<Common::DynamicLibrary> OpenOwnImage() {
    Dl_info info{};
    if (dladdr(AzurionMoltenVKAnchor(), &info) == 0 || info.dli_fname == nullptr) {
        LOG_CRITICAL(Frontend, "Could not locate the image that contains MoltenVK");
        return nullptr;
    }

    void* handle = dlopen(info.dli_fname, RTLD_NOW | RTLD_NOLOAD);
    if (handle == nullptr) {
        LOG_CRITICAL(Frontend, "dlopen({}) failed: {}", info.dli_fname, dlerror());
        return nullptr;
    }
    return std::make_shared<Common::DynamicLibrary>(handle);
}

} // Anonymous namespace

EmuWindow_iOS::EmuWindow_iOS(void* metal_layer, unsigned width, unsigned height)
    : driver_library{OpenOwnImage()} {
    // The core names this platform "MacOS", but all it means is "present into a CAMetalLayer",
    // which holds on iOS as well.
    window_info.type = Frontend::WindowSystemType::MacOS;
    window_info.render_surface = metal_layer;
    Resize(width, height);
}

EmuWindow_iOS::~EmuWindow_iOS() = default;

std::unique_ptr<Frontend::GraphicsContext> EmuWindow_iOS::CreateSharedContext() const {
    return std::make_unique<GraphicsContext_iOS>(driver_library);
}

std::shared_ptr<Common::DynamicLibrary> EmuWindow_iOS::GetDriverLibrary() {
    return driver_library;
}

void EmuWindow_iOS::Resize(unsigned width, unsigned height) {
    UpdateCurrentFramebufferLayout(width, height, height > width);
}
