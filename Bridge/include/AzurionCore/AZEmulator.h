// Copyright 2026 Azurion Project
// Licensed under GPLv3 or any later version
// Refer to the LICENSE file included.

// Public Objective-C API of the Azahar core, as seen from Swift.
// Nothing in this header may include C++: Swift imports it as a plain clang module.

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@class CAMetalLayer;

NS_ASSUME_NONNULL_BEGIN

/// 3DS buttons. Values follow Azahar's Settings::NativeButton order.
typedef NS_ENUM(NSInteger, AZButton) {
    AZButtonA NS_SWIFT_NAME(a) = 0,
    AZButtonB NS_SWIFT_NAME(b),
    AZButtonX NS_SWIFT_NAME(x),
    AZButtonY NS_SWIFT_NAME(y),
    AZButtonUp NS_SWIFT_NAME(up),
    AZButtonDown NS_SWIFT_NAME(down),
    AZButtonLeft NS_SWIFT_NAME(left),
    AZButtonRight NS_SWIFT_NAME(right),
    AZButtonL NS_SWIFT_NAME(l),
    AZButtonR NS_SWIFT_NAME(r),
    AZButtonStart NS_SWIFT_NAME(start),
    AZButtonSelect NS_SWIFT_NAME(select),
    AZButtonDebug NS_SWIFT_NAME(debug),
    AZButtonGPIO14 NS_SWIFT_NAME(gpio14),
    AZButtonZL NS_SWIFT_NAME(zl),
    AZButtonZR NS_SWIFT_NAME(zr),
    AZButtonHome NS_SWIFT_NAME(home),
    AZButtonPower NS_SWIFT_NAME(power),
} NS_SWIFT_NAME(EmulatorButton);

/// Analog inputs. Values follow Azahar's Settings::NativeAnalog order.
typedef NS_ENUM(NSInteger, AZStick) {
    AZStickCirclePad NS_SWIFT_NAME(circlePad) = 0,
    AZStickCStick NS_SWIFT_NAME(cStick),
} NS_SWIFT_NAME(EmulatorStick);

/// Why an emulation session ended.
typedef NS_ENUM(NSInteger, AZExitReason) {
    /// The user stopped the game, or the game requested a shutdown.
    AZExitReasonStopped = 0,
    /// The file is still encrypted. Only decrypted dumps are supported.
    AZExitReasonEncryptedGame,
    /// The file is not a 3DS game Azahar can load.
    AZExitReasonInvalidFormat,
    /// The game needs system files that are not installed.
    AZExitReasonMissingSystemFiles,
    /// The emulated CPU crashed.
    AZExitReasonCoreCrashed,
    /// Any other core error. See the log for details.
    AZExitReasonOtherError,
} NS_SWIFT_NAME(EmulatorExitReason);

typedef struct {
    double gameFPS;
    /// 1.0 means full speed.
    double emulationSpeed;
} AZPerformance NS_SWIFT_NAME(EmulatorPerformance);

/// Drives the Azahar core. The core supports a single running game, so there is one shared
/// instance. Every method must be called from the main thread; emulation itself runs on a
/// dedicated background thread.
NS_SWIFT_NAME(Emulator)
@interface AZEmulator : NSObject

@property(class, readonly, strong) AZEmulator* sharedEmulator NS_SWIFT_NAME(shared);

/// Whether the process may generate code at runtime (a debugger such as StikDebug enabled JIT).
/// Without JIT the core falls back to the much slower interpreter.
@property(class, readonly, getter=isJITAvailable) BOOL JITAvailable;

@property(readonly, getter=isRunning) BOOL running;
@property(readonly, getter=isPaused) BOOL paused;

- (instancetype)init NS_UNAVAILABLE;

/// Points the core at its data directory (saves, config, shader cache, system files).
/// Call once at launch, before booting any game.
- (void)configureWithUserDirectory:(NSURL*)directory;

/// Boots a decrypted game (.3ds/.cci/.cxi/.3dsx/...) and renders into `layer`.
/// `drawableSize` is in pixels. `onExit` runs on the main queue when the session ends.
- (void)bootGameAtURL:(NSURL*)gameURL
                layer:(CAMetalLayer*)layer
         drawableSize:(CGSize)drawableSize
               onExit:(void (^)(AZExitReason reason))onExit
    NS_SWIFT_NAME(boot(game:layer:drawableSize:onExit:));

- (void)pause;
- (void)resume;
/// Requests a shutdown. `onExit` from the boot call fires once the core has stopped.
- (void)stop;

/// Call when the layer's drawable size (pixels) or orientation changes.
- (void)drawableSizeDidChange:(CGSize)drawableSize NS_SWIFT_NAME(drawableSizeDidChange(_:));

- (void)pressButton:(AZButton)button NS_SWIFT_NAME(press(_:));
- (void)releaseButton:(AZButton)button NS_SWIFT_NAME(release(_:));

/// x and y are in [-1, 1]; +y is up.
- (void)setStick:(AZStick)stick x:(float)x y:(float)y NS_SWIFT_NAME(setStick(_:x:y:));

/// Touch positions are in drawable pixels, in the same space as `drawableSize`.
- (void)touchBeganAtPoint:(CGPoint)point NS_SWIFT_NAME(touchBegan(at:));
- (void)touchMovedToPoint:(CGPoint)point NS_SWIFT_NAME(touchMoved(to:));
- (void)touchEnded;

/// Performance since the previous call. Zeroes when nothing is running.
- (AZPerformance)takePerformance;

@end

NS_ASSUME_NONNULL_END
