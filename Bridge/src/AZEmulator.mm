// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

// Boot and run loop follow RunCitra() from Azahar's Android frontend (jni/native.cpp).

#import <QuartzCore/CAMetalLayer.h>

#include <algorithm>
#include <atomic>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <string>
#include "common/file_util.h"
#include "common/logging/backend.h"
#include "common/logging/log.h"
#include "common/scope_exit.h"
#include "common/settings.h"
#include "core/core.h"
#include "core/frontend/applets/default_applets.h"
#include "core/loader/loader.h"
#include "video_core/gpu.h"
#include "video_core/rasterizer_interface.h"
#include "video_core/renderer_base.h"

#import "AZEmulator.h"
#include "emu_window_ios.h"
#include "input_ios.h"
#include "jit_ios.h"

namespace {

/// One boot of one game. Created and destroyed on the main thread; the emulation thread only
/// reads `window` and the flags.
struct Session {
    std::unique_ptr<EmuWindow_iOS> window;
    std::atomic_bool stop_requested{false};
    std::atomic_bool paused{false};
    std::mutex pause_mutex;
    std::condition_variable pause_cv;
};

AZExitReason ExitReasonFor(Core::System::ResultStatus status) {
    using Status = Core::System::ResultStatus;
    switch (status) {
    case Status::Success:
    case Status::ShutdownRequested:
        return AZExitReasonStopped;
    case Status::ErrorLoader_ErrorEncrypted:
        return AZExitReasonEncryptedGame;
    case Status::ErrorGetLoader:
    case Status::ErrorLoader_ErrorInvalidFormat:
        return AZExitReasonInvalidFormat;
    case Status::ErrorSystemFiles:
        return AZExitReasonMissingSystemFiles;
    case Status::ErrorCoreExceptionRaised:
        return AZExitReasonCoreCrashed;
    default:
        return AZExitReasonOtherError;
    }
}

/// Runs on the emulation thread until the game exits or `session.stop_requested` is set.
Core::System::ResultStatus RunGame(Session& session, const std::string& path) {
    Core::System& system{Core::System::GetInstance()};

    Settings::values.graphics_api = Settings::GraphicsAPI::Vulkan;
    Settings::values.use_cpu_jit = JitIOS::IsAvailable();
    if (!Settings::values.use_cpu_jit) {
        LOG_WARNING(Frontend, "JIT is not available, falling back to the interpreter");
    }

    u64 program_id{};
    FileUtil::SetCurrentRomPath(path);
    auto app_loader = Loader::GetLoader(path);
    if (app_loader) {
        app_loader->ReadProgramId(program_id);
        system.RegisterAppLoaderEarly(app_loader);
    }
    system.ApplySettings();
    Settings::LogSettings();

    // TODO: native software keyboard (needed for naming Pokémon) and Mii selector applets.
    Frontend::RegisterDefaultApplets(system);

    const Core::System::ResultStatus load_result{system.Load(*session.window, path)};
    if (load_result != Core::System::ResultStatus::Success) {
        return load_result;
    }

    system.GPU().ApplyPerProgramSettings(program_id);
    // TODO: surface shader cache progress in the UI.
    system.GPU().Renderer().Rasterizer()->LoadDefaultDiskResources(
        session.stop_requested,
        [](VideoCore::LoadCallbackStage, std::size_t, std::size_t, const std::string&) {});

    SCOPE_EXIT({ system.Shutdown(); });

    system.RegisterCoreLoopThreadId();

    while (!session.stop_requested) {
        if (session.paused) {
            // Ensure no audio bleeds out while the game is paused.
            const float volume = Settings::values.volume.GetValue();
            SCOPE_EXIT({ Settings::values.volume = volume; });
            Settings::values.volume = 0;

            std::unique_lock lock{session.pause_mutex};
            session.pause_cv.wait(lock,
                                  [&] { return !session.paused || session.stop_requested; });
            continue;
        }

        const Core::System::ResultStatus result{system.RunLoop()};
        if (result != Core::System::ResultStatus::Success) {
            return result;
        }
    }

    return Core::System::ResultStatus::Success;
}

} // Anonymous namespace

@implementation AZEmulator {
    std::shared_ptr<Session> _session;
    /// Kept alive for as long as the core may render into it.
    CAMetalLayer* _layer;
    BOOL _configured;
}

+ (AZEmulator*)sharedEmulator {
    static AZEmulator* instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      instance = [[AZEmulator alloc] initPrivate];
    });
    return instance;
}

- (instancetype)initPrivate {
    return [super init];
}

+ (BOOL)isJITAvailable {
    return JitIOS::IsAvailable();
}

- (BOOL)isRunning {
    return _session != nullptr;
}

- (BOOL)isPaused {
    return _session != nullptr && _session->paused;
}

- (void)configureWithUserDirectory:(NSURL*)directory {
    if (_configured) {
        return;
    }
    _configured = YES;

    FileUtil::SetUserPath(std::string{directory.fileSystemRepresentation} + "/");
    Common::Log::Initialize();
    Common::Log::Start();
    InputIOS::Init();

    LOG_INFO(Frontend, "Azurion configured, JIT {}",
             JitIOS::IsAvailable() ? "available" : "unavailable");
}

- (void)bootGameAtURL:(NSURL*)gameURL
                layer:(CAMetalLayer*)layer
         drawableSize:(CGSize)drawableSize
               onExit:(void (^)(AZExitReason))onExit {
    NSAssert(_configured, @"Call configureWithUserDirectory: before booting a game");
    if (_session) {
        LOG_WARNING(Frontend, "A game is already running");
        return;
    }

    auto session = std::make_shared<Session>();
    session->window = std::make_unique<EmuWindow_iOS>(
        (__bridge void*)layer, static_cast<unsigned>(drawableSize.width),
        static_cast<unsigned>(drawableSize.height));
    _session = session;
    _layer = layer;

    const std::string path{gameURL.fileSystemRepresentation};
    __weak AZEmulator* weakSelf = self;

    NSThread* thread = [[NSThread alloc] initWithBlock:^{
      const Core::System::ResultStatus status = RunGame(*session, path);
      dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf finishSession:session];
        onExit(ExitReasonFor(status));
      });
    }];
    thread.name = @"EmuThread";
    thread.stackSize = 8 * 1024 * 1024;
    thread.qualityOfService = NSQualityOfServiceUserInteractive;
    [thread start];
}

- (void)finishSession:(const std::shared_ptr<Session>&)session {
    if (_session == session) {
        _session.reset();
        _layer = nil;
    }
    InputIOS::SetStick(Settings::NativeAnalog::CirclePad, 0.0f, 0.0f);
    InputIOS::SetStick(Settings::NativeAnalog::CStick, 0.0f, 0.0f);
}

- (void)pause {
    if (_session) {
        _session->paused = true;
    }
}

- (void)resume {
    if (_session) {
        std::scoped_lock lock{_session->pause_mutex};
        _session->paused = false;
        _session->pause_cv.notify_all();
    }
}

- (void)stop {
    if (_session) {
        std::scoped_lock lock{_session->pause_mutex};
        _session->stop_requested = true;
        _session->pause_cv.notify_all();
    }
}

- (void)drawableSizeDidChange:(CGSize)drawableSize {
    if (_session) {
        _session->window->Resize(static_cast<unsigned>(drawableSize.width),
                                 static_cast<unsigned>(drawableSize.height));
    }
}

- (void)pressButton:(AZButton)button {
    InputIOS::SetButton(static_cast<int>(button), true);
}

- (void)releaseButton:(AZButton)button {
    InputIOS::SetButton(static_cast<int>(button), false);
}

- (void)setStick:(AZStick)stick x:(float)x y:(float)y {
    InputIOS::SetStick(static_cast<int>(stick), x, y);
}

- (void)touchBeganAtPoint:(CGPoint)point {
    if (_session) {
        _session->window->TouchPressed(static_cast<unsigned>(std::max(point.x, 0.0)),
                                       static_cast<unsigned>(std::max(point.y, 0.0)));
    }
}

- (void)touchMovedToPoint:(CGPoint)point {
    if (_session) {
        _session->window->TouchMoved(static_cast<unsigned>(std::max(point.x, 0.0)),
                                     static_cast<unsigned>(std::max(point.y, 0.0)));
    }
}

- (void)touchEnded {
    if (_session) {
        _session->window->TouchReleased();
    }
}

- (AZPerformance)takePerformance {
    Core::System& system{Core::System::GetInstance()};
    if (!_session || !system.IsPoweredOn()) {
        return AZPerformance{0.0, 0.0};
    }
    const auto results = system.GetAndResetPerfStats();
    return AZPerformance{results.game_fps, results.emulation_speed};
}

@end
