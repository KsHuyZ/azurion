// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

#pragma once

/// Feeds touch controls and game controllers into the core.
/// Buttons go through Azahar's built-in keyboard engine (key code = NativeButton index);
/// sticks go through a small analog engine of our own, since the keyboard one is digital only.
namespace InputIOS {

/// Registers the input engines and binds the core's input profile to them.
void Init();
void Shutdown();

/// @param button a Settings::NativeButton value
void SetButton(int button, bool pressed);

/// @param stick a Settings::NativeAnalog value
/// @param x, y in [-1, 1], +y is up
void SetStick(int stick, float x, float y);

} // namespace InputIOS
