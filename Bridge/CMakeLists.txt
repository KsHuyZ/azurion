# Azurion bridge: the Objective-C++ layer between the SwiftUI app and the Azahar core.
#
# This directory is built from inside Azahar's own CMake tree (see
# patches/azahar/0001-ios-frontend-hook.patch), so every core target is available here.
# The result is AzurionCore.framework: a dynamic framework that statically contains the
# whole core plus MoltenVK, and exposes a small Objective-C API to Swift.

set(AZURION_PUBLIC_HEADERS
    include/AzurionCore/AzurionCore.h
    include/AzurionCore/AZEmulator.h
)

add_library(AzurionCore SHARED
    ${AZURION_PUBLIC_HEADERS}
    src/AZEmulator.mm
    src/emu_window_ios.cpp
    src/emu_window_ios.h
    src/input_ios.cpp
    src/input_ios.h
    src/jit_ios.cpp
    src/jit_ios.h
    src/moltenvk_anchor.cpp
)

set_target_properties(AzurionCore PROPERTIES
    FRAMEWORK TRUE
    PUBLIC_HEADER "${AZURION_PUBLIC_HEADERS}"
    MACOSX_FRAMEWORK_IDENTIFIER org.azurion.core
    MACOSX_FRAMEWORK_SHORT_VERSION_STRING 0.1.0
    MACOSX_FRAMEWORK_BUNDLE_VERSION 1
    MACOSX_FRAMEWORK_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/Info.plist.in
    INSTALL_NAME_DIR "@rpath"
    BUILD_WITH_INSTALL_NAME_DIR TRUE
    # scripts/build-core.sh picks the framework up from here.
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/azurion
)

target_include_directories(AzurionCore PRIVATE
    include/AzurionCore
    src
)

target_compile_options(AzurionCore PRIVATE
    $<$<COMPILE_LANGUAGE:OBJCXX>:-fobjc-arc>
)

target_link_libraries(AzurionCore PRIVATE
    audio_core
    citra_common
    citra_core
    input_common
    network
    video_core
    "-framework Foundation"
    "-framework UIKit"
    "-framework QuartzCore"
    "-framework Metal"
    "-framework IOSurface"
    "-framework AVFoundation"
    "-framework AudioToolbox"
    "-framework CoreGraphics"
)

# Swift imports the framework as a clang module.
add_custom_command(TARGET AzurionCore POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_BUNDLE_DIR:AzurionCore>/Modules"
    COMMAND ${CMAKE_COMMAND} -E copy
            "${CMAKE_CURRENT_SOURCE_DIR}/module.modulemap"
            "$<TARGET_BUNDLE_DIR:AzurionCore>/Modules/module.modulemap"
)
