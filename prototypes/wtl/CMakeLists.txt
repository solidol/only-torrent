cmake_minimum_required(VERSION 3.24)
project(OnlyTorrentWtlPrototype LANGUAGES CXX RC)
if(NOT MSVC OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "Use MSVC with the x64 architecture")
endif()
set(WTL_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../deps/wtl-10.01" CACHE PATH "Unmodified WTL 10.01 root")
find_path(WTL_INCLUDE_DIR atlapp.h PATHS "${WTL_ROOT}/Include" NO_DEFAULT_PATH REQUIRED)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
get_filename_component(OT_ICON "${CMAKE_CURRENT_SOURCE_DIR}/../../resources/otorrent.ico" ABSOLUTE)
configure_file(resources/Prototype.rc.in "${CMAKE_CURRENT_BINARY_DIR}/Prototype.rc" @ONLY)
add_executable(otorrent-wtl-prototype WIN32
  src/Main.cpp src/Ot.MainFrame.cpp src/Ot.DemoModel.cpp src/Ot.DetailsPane.cpp src/Ot.FencePainter.cpp
  "${CMAKE_CURRENT_BINARY_DIR}/Prototype.rc")
target_include_directories(otorrent-wtl-prototype PRIVATE "${WTL_INCLUDE_DIR}" src resources)
target_compile_features(otorrent-wtl-prototype PRIVATE cxx_std_17)
target_compile_definitions(otorrent-wtl-prototype PRIVATE UNICODE _UNICODE WINVER=0x0601
  _WIN32_WINNT=0x0601 NOMINMAX WIN32_LEAN_AND_MEAN _CRT_SECURE_NO_WARNINGS)
target_compile_options(otorrent-wtl-prototype PRIVATE /W4 /permissive- /utf-8 /EHsc
  $<$<CONFIG:Release>:/O2> $<$<CONFIG:Release>:/Gy> $<$<CONFIG:Release>:/Gw>)
target_link_options(otorrent-wtl-prototype PRIVATE /MANIFEST:NO /SUBSYSTEM:WINDOWS,6.01
  $<$<CONFIG:Release>:/OPT:REF> $<$<CONFIG:Release>:/OPT:ICF> $<$<CONFIG:Release>:/INCREMENTAL:NO>)
target_link_libraries(otorrent-wtl-prototype PRIVATE comctl32 uxtheme ole32)
add_custom_command(TARGET otorrent-wtl-prototype POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/README.md" "$<TARGET_FILE_DIR:otorrent-wtl-prototype>/README.md")
