# SPDX-FileCopyrightText: 2026 Kaito Udagawa <umireon@kaito.tokyo>
#
# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.28)

### Options
set(PLUGIN_DISPLAY_NAME "Live Video Macro" CACHE STRING "Display name of plugin")
set(PLUGIN_AUTHOR "Kaito Udagawa" CACHE STRING "Author of plugin")
set(PLUGIN_EMAIL "umireon@kaito.tokyo" CACHE STRING "Author email of plugin")
set(PLUGIN_BUILD_NUMBER "1" CACHE STRING "Build number in plugin metadata")
set(PLUGIN_BUNDLE_ID "tokyo.kaito.live-video-macro" CACHE STRING "Bundle ID of plugin installer")
set(PACKAGE_VERSION_SUFFIX "" CACHE STRING "Version suffix for plugin package")

### Project
block(PROPAGATE PLUGIN_VERSION)
  file(READ "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" VERSION_CONTENT)
  string(STRIP "${VERSION_CONTENT}" PLUGIN_VERSION)
endblock()

project(live-video-macro VERSION "${PLUGIN_VERSION}" LANGUAGES C CXX)
set(PLUGIN_NAME "${CMAKE_PROJECT_NAME}")

include(GNUInstallDirs)

### Global configurations
set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED TRUE)
set(CMAKE_C_EXTENSIONS FALSE)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED TRUE)
set(CMAKE_CXX_EXTENSIONS FALSE)
set(CMAKE_POSITION_INDEPENDENT_CODE TRUE)

if(MSVC)
  add_compile_definitions(NOMINMAX WIN32_LEAN_AND_MEAN UNICODE _UNICODE)
  add_compile_options(
    /utf-8
    /Zc:preprocessor
    $<$<COMPILE_LANGUAGE:CXX>:/permissive->
    $<$<COMPILE_LANGUAGE:CXX>:/Zc:__cplusplus>
  )
else()
  add_compile_options(-fno-omit-frame-pointer -fstack-protector-strong)
endif()

set(CMAKE_MAP_IMPORTED_CONFIG_RELWITHDEBINFO RelWithDebInfo Release)

### Configure paths
if(DEFINED ENV{PLUGIN_BUILD_DIR})
  set(PLUGIN_BUILD_DIR "$ENV{PLUGIN_BUILD_DIR}")
else()
  set(PLUGIN_BUILD_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
endif()

if(APPLE)
  list(
    PREPEND
    CMAKE_PREFIX_PATH
    "${PLUGIN_BUILD_DIR}/.deps/obs-deps-prebuilt"
    "${PLUGIN_BUILD_DIR}/.deps/obs-deps-qt6"
    "${PLUGIN_BUILD_DIR}/obs_installed"
    "${PLUGIN_BUILD_DIR}/obs_installed/Frameworks"
    "${PLUGIN_BUILD_DIR}/vcpkg_ort_installed/universal-osx"
    "${PLUGIN_BUILD_DIR}/ort_installed"
    "${PLUGIN_BUILD_DIR}/vcpkg_installed/universal-osx-obs"
  )
endif()

### Package dependencies
find_package(PkgConfig QUIET)

find_package(libobs REQUIRED)
find_package(obs-frontend-api REQUIRED)

### Plugin main
add_library(${CMAKE_PROJECT_NAME}_options INTERFACE)

if(APPLE OR NOT MSVC)
  target_compile_definitions(${CMAKE_PROJECT_NAME}_options INTERFACE SIMDE_ENABLE_OPENMP)
  target_compile_options(${CMAKE_PROJECT_NAME}_options INTERFACE -fopenmp-simd -Wall -Wextra -Werror)
endif()

add_library(${CMAKE_PROJECT_NAME} MODULE)

target_link_libraries(
  ${CMAKE_PROJECT_NAME}
  PRIVATE
    ${CMAKE_PROJECT_NAME}_options
    OBS::libobs
    OBS::obs-frontend-api
)

target_sources(
  ${CMAKE_PROJECT_NAME}
  PRIVATE
    src/plugin-main.cpp
)

### Hide symbols
if(APPLE)
  target_link_options(
    ${CMAKE_PROJECT_NAME}
    PRIVATE "-Wl,-exported_symbols_list,${CMAKE_CURRENT_SOURCE_DIR}/src/exported_symbols_macos.txt"
  )
elseif(MSVC)
  target_sources(${CMAKE_PROJECT_NAME} PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/src/exported_symbols_windows.def")
else()
  target_link_options(
    ${CMAKE_PROJECT_NAME}
    PRIVATE "-Wl,--version-script,${CMAKE_CURRENT_SOURCE_DIR}/src/exported_symbols_linux.map" "-Wl,-Bsymbolic"
  )
endif()

### Install configurations
if(APPLE)
  configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/packaging/pkg/Distribution.xml.in"
    "${CMAKE_CURRENT_BINARY_DIR}/Distribution"
    @ONLY
  )

  set_target_properties(${CMAKE_PROJECT_NAME} PROPERTIES BUNDLE TRUE BUNDLE_EXTENSION "plugin")
  set_source_files_properties(${EFFECTS_FILES} PROPERTIES MACOSX_PACKAGE_LOCATION "Resources/effects")
  set_source_files_properties(${LOCALE_FILES} PROPERTIES MACOSX_PACKAGE_LOCATION "Resources/locale")
  set_source_files_properties(${MODELS_FILES} PROPERTIES MACOSX_PACKAGE_LOCATION "Resources/models")
  target_sources(${CMAKE_PROJECT_NAME} PRIVATE ${EFFECTS_FILES} ${LOCALE_FILES} ${MODELS_FILES})

  install(
    TARGETS "${CMAKE_PROJECT_NAME}"
    BUNDLE DESTINATION "Library/Application Support/obs-studio/plugins"
    LIBRARY DESTINATION "Library/Application Support/obs-studio/plugins"
  )
else()
  message("Installing on this platform is not supported officially.")
endif()

### Export variables
block()
  set(SH_CONTENT "")
  set(PS1_CONTENT "")

  foreach(VAR_NAME PLUGIN_BUNDLE_ID PLUGIN_DISPLAY_NAME PLUGIN_NAME PLUGIN_VERSION)
    set(VAR_VALUE "${${VAR_NAME}}")
    if(NOT VAR_VALUE MATCHES [[^[-A-Za-z0-9._ ]+$]])
      message(FATAL_ERROR "${VAR_NAME} contains unsupported characters: ${VAR_VALUE}")
    endif()
    string(APPEND SH_CONTENT "${VAR_NAME}=\'${VAR_VALUE}\'\n")
    string(APPEND PS1_CONTENT "\$${VAR_NAME} = \'${VAR_VALUE}\'\n")
  endforeach()

  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/cmake_export.sh" "${SH_CONTENT}")
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/cmake_export.ps1" "${PS1_CONTENT}")
endblock()
