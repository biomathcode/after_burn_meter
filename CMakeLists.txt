cmake_minimum_required(VERSION 3.26)
project(Afterburn VERSION 0.4.0 LANGUAGES CXX OBJCXX Swift)

if(NOT APPLE OR NOT CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
    message(FATAL_ERROR "Afterburn requires an Apple Silicon Mac. SmartSpectra does not support Intel macOS.")
endif()

set(CMAKE_OSX_DEPLOYMENT_TARGET "14.0" CACHE STRING "Minimum macOS version" FORCE)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(AFTERBURN_DEVELOPMENT_TEAM "" CACHE STRING "Apple Development team ID for live measurement")
set(SMARTSPECTRA_SDK_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/.vendor/smartspectra" CACHE PATH "SDK install prefix")
list(PREPEND CMAKE_PREFIX_PATH "${SMARTSPECTRA_SDK_ROOT}")
find_package(SmartSpectra CONFIG REQUIRED)
find_package(Python3 REQUIRED COMPONENTS Interpreter)

file(GLOB_RECURSE APP_SWIFT CONFIGURE_DEPENDS App/*.swift Sources/AfterburnCore/*.swift)
set(APP_RESOURCES
    Resources/exercises.json
    Resources/EXERCISES-LICENSE.txt
    Resources/THIRD_PARTY_NOTICES.md
)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/Resources/AppIcon.icns")
    list(APPEND APP_RESOURCES Resources/AppIcon.icns)
endif()
set_source_files_properties(${APP_RESOURCES} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)

add_executable(Afterburn MACOSX_BUNDLE
    ${APP_SWIFT}
    App/Bridge/AfterburnSensor.mm
    App/Bridge/AfterburnSensor.h
    App/Bridge/Afterburn-Bridging-Header.h
    ${APP_RESOURCES}
)
target_include_directories(Afterburn PRIVATE App/Bridge)
target_link_libraries(Afterburn PRIVATE SmartSpectra::SDK
    "-framework AppKit" "-framework AVFoundation" "-framework Security"
    "-framework CoreGraphics" "-framework Accelerate" "-lc++")

set_target_properties(Afterburn PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/App/Info.plist"
    XCODE_GENERATE_SCHEME YES
    XCODE_ATTRIBUTE_SWIFT_VERSION "5.0"
    XCODE_ATTRIBUTE_SWIFT_STRICT_CONCURRENCY "minimal"
    XCODE_ATTRIBUTE_SWIFT_OBJC_BRIDGING_HEADER "${CMAKE_CURRENT_SOURCE_DIR}/App/Bridge/Afterburn-Bridging-Header.h"
    XCODE_ATTRIBUTE_CLANG_ENABLE_MODULES YES
    XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
    XCODE_ATTRIBUTE_ENABLE_HARDENED_RUNTIME YES
    XCODE_ATTRIBUTE_ENABLE_APP_SANDBOX NO
    XCODE_ATTRIBUTE_ENABLE_USER_SCRIPT_SANDBOXING NO
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "app.afterburn.meter"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE "Automatic"
    XCODE_ATTRIBUTE_OTHER_CODE_SIGN_FLAGS "$<$<CONFIG:Debug>:--timestamp=none>"
    XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Apple Development"
    XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "${AFTERBURN_DEVELOPMENT_TEAM}"
    XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/App/Afterburn.entitlements"
    XCODE_ATTRIBUTE_MACOSX_DEPLOYMENT_TARGET "14.0"
    XCODE_ATTRIBUTE_LD_RUNPATH_SEARCH_PATHS "@executable_path/../Resources/SmartSpectraRuntime @executable_path/../Resources/SmartSpectraRuntime/smartspectra"
    XCODE_ATTRIBUTE_COMBINE_HIDPI_IMAGES YES
)

add_custom_command(TARGET Afterburn POST_BUILD
    COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/scripts/embed_runtime.py"
        "$<TARGET_BUNDLE_DIR:Afterburn>" "${SMARTSPECTRA_SDK_ROOT}"
    COMMENT "Embedding SmartSpectra runtime, models and licence notices"
    VERBATIM
)

