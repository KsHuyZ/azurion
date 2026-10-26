// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

// Referencing vkGetInstanceProcAddr keeps MoltenVK's loader entry point linked into the framework,
// and its address tells EmuWindow_iOS which image to hand to the core. Kept in its own file so the
// loose declaration below never meets the real one from <vulkan/vulkan.h>.

extern "C" void vkGetInstanceProcAddr();

extern "C" void* AzurionMoltenVKAnchor() {
    return reinterpret_cast<void*>(&vkGetInstanceProcAddr);
}
