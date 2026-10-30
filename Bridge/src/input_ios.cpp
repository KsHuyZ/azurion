// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

#include <algorithm>
#include <array>
#include <atomic>
#include <memory>
#include <tuple>
#include "common/common_types.h"
#include "common/param_package.h"
#include "common/settings.h"
#include "core/frontend/input.h"
#include "input_common/main.h"
#include "input_ios.h"

namespace InputIOS {

namespace {

constexpr char ButtonEngine[] = "azurion_button";
constexpr char StickEngine[] = "azurion_stick";

/// The core samples buttons on emulated time (HID 234 times a second) and games read them once a
/// frame. Without JIT the core runs at a few percent of full speed, so a quick tap can start and
/// end between two frames and the game never sees it. 16 HID samples is ~68ms of emulated time,
/// two frames at 30fps.
constexpr int MinPressSamples = 16;

struct ButtonState {
    std::atomic_bool held{false};
    /// Bumped on every press, so a device notices a tap that was released before its next read.
    std::atomic<u32> presses{0};
};

std::array<ButtonState, Settings::NativeButton::NumButtons> g_buttons;

/// Reports each press for at least MinPressSamples reads, then follows the touch. Several devices
/// can read one button (two IR services read ZL and ZR), so each counts its own reads.
class Button final : public Input::ButtonDevice {
public:
    explicit Button(const ButtonState& state_)
        : state{state_}, seen_presses{state_.presses.load(std::memory_order_relaxed)} {}

    bool GetStatus() const override {
        const u32 presses = state.presses.load(std::memory_order_relaxed);
        if (presses != seen_presses) {
            seen_presses = presses;
            samples_left = MinPressSamples;
        }
        if (samples_left > 0) {
            --samples_left;
            return true;
        }
        return state.held.load(std::memory_order_relaxed);
    }

private:
    const ButtonState& state;
    // Only touched by the thread that reads this device.
    mutable u32 seen_presses;
    mutable int samples_left = 0;
};

class ButtonFactory final : public Input::Factory<Input::ButtonDevice> {
public:
    /// params: "button" is the Settings::NativeButton index
    std::unique_ptr<Input::ButtonDevice> Create(const Common::ParamPackage& params) override {
        const int index =
            std::clamp(params.Get("button", 0), 0, Settings::NativeButton::NumButtons - 1);
        return std::make_unique<Button>(g_buttons[index]);
    }
};

struct StickState {
    std::atomic<float> x{0.0f};
    std::atomic<float> y{0.0f};
};

std::array<StickState, Settings::NativeAnalog::NumAnalogs> g_sticks;

class Stick final : public Input::AnalogDevice {
public:
    explicit Stick(const StickState& state_) : state{state_} {}

    std::tuple<float, float> GetStatus() const override {
        return {state.x.load(std::memory_order_relaxed), state.y.load(std::memory_order_relaxed)};
    }

private:
    const StickState& state;
};

class StickFactory final : public Input::Factory<Input::AnalogDevice> {
public:
    /// params: "stick" is the Settings::NativeAnalog index
    std::unique_ptr<Input::AnalogDevice> Create(const Common::ParamPackage& params) override {
        const int index =
            std::clamp(params.Get("stick", 0), 0, Settings::NativeAnalog::NumAnalogs - 1);
        return std::make_unique<Stick>(g_sticks[index]);
    }
};

} // Anonymous namespace

void Init() {
    InputCommon::Init();
    Input::RegisterFactory<Input::ButtonDevice>(ButtonEngine, std::make_shared<ButtonFactory>());
    Input::RegisterFactory<Input::AnalogDevice>(StickEngine, std::make_shared<StickFactory>());

    auto& profile = Settings::values.current_input_profile;
    for (int i = 0; i < Settings::NativeButton::NumButtons; ++i) {
        Common::ParamPackage params;
        params.Set("engine", ButtonEngine);
        params.Set("button", i);
        profile.buttons[i] = params.Serialize();
    }
    for (int i = 0; i < Settings::NativeAnalog::NumAnalogs; ++i) {
        Common::ParamPackage params;
        params.Set("engine", StickEngine);
        params.Set("stick", i);
        profile.analogs[i] = params.Serialize();
    }
}

void Shutdown() {
    Input::UnregisterFactory<Input::ButtonDevice>(ButtonEngine);
    Input::UnregisterFactory<Input::AnalogDevice>(StickEngine);
    InputCommon::Shutdown();
}

void SetButton(int button, bool pressed) {
    if (button < 0 || button >= Settings::NativeButton::NumButtons) {
        return;
    }
    ButtonState& state = g_buttons[button];
    state.held.store(pressed, std::memory_order_relaxed);
    if (pressed) {
        state.presses.fetch_add(1, std::memory_order_relaxed);
    }
}

void SetStick(int stick, float x, float y) {
    if (stick < 0 || stick >= Settings::NativeAnalog::NumAnalogs) {
        return;
    }
    g_sticks[stick].x.store(std::clamp(x, -1.0f, 1.0f), std::memory_order_relaxed);
    g_sticks[stick].y.store(std::clamp(y, -1.0f, 1.0f), std::memory_order_relaxed);
}

} // namespace InputIOS
