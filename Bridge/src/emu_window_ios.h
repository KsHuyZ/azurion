// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

#pragma once

#include <memory>
#include "core/frontend/emu_window.h"

namespace Common {
class DynamicLibrary;
}

/// Window backed by a CAMetalLayer. The Vulkan renderer creates a VK_EXT_metal_surface on the
/// layer and MoltenVK translates everything to Metal.
/// Modelled on EmuWindow_Android_Vulkan from Azahar's Android frontend.
class EmuWindow_iOS final : public Frontend::EmuWindow {
public:
    /// @param metal_layer CAMetalLayer* the renderer presents into
    /// @param width, height drawable size in pixels
    EmuWindow_iOS(void* metal_layer, unsigned width, unsigned height);
    ~EmuWindow_iOS() override;

    void PollEvents() override {}

    std::unique_ptr<Frontend::GraphicsContext> CreateSharedContext() const override;

    std::shared_ptr<Common::DynamicLibrary> GetDriverLibrary() override;

    /// Recomputes the screen layout for a new drawable size, in pixels.
    void Resize(unsigned width, unsigned height);

private:
    std::shared_ptr<Common::DynamicLibrary> driver_library;
};
