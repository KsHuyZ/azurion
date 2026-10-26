// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

#include <algorithm>
#include <array>
#include <atomic>
#include <memory>
#include <tuple>
#include "common/param_package.h"
#include "common/settings.h"
#include "core/frontend/input.h"
#include "input_common/keyboard.h"
#include "input_common/main.h"
#include "input_ios.h"

namespace InputIOS {

namespace {

constexpr char StickEngine[] = "azurion_stick";

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
    Input::RegisterFactory<Input::AnalogDevice>(StickEngine, std::make_shared<StickFactory>());

    auto& profile = Settings::values.current_input_profile;
    for (int i = 0; i < Settings::NativeButton::NumButtons; ++i) {
        profile.buttons[i] = InputCommon::GenerateKeyboardParam(i);
    }
    for (int i = 0; i < Settings::NativeAnalog::NumAnalogs; ++i) {
        Common::ParamPackage params;
        params.Set("engine", StickEngine);
        params.Set("stick", i);
        profile.analogs[i] = params.Serialize();
    }
}

void Shutdown() {
    Input::UnregisterFactory<Input::AnalogDevice>(StickEngine);
    InputCommon::Shutdown();
}

void SetButton(int button, bool pressed) {
    if (button < 0 || button >= Settings::NativeButton::NumButtons) {
        return;
    }
    if (pressed) {
        InputCommon::GetKeyboard()->PressKey(button);
    } else {
        InputCommon::GetKeyboard()->ReleaseKey(button);
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
