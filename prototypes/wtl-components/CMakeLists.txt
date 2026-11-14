cmake_minimum_required(VERSION 3.24)
project(OnlyTorrentWtlComponents LANGUAGES CXX RC)
if(NOT MSVC OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "Use MSVC with the x64 architecture")
endif()
set(WTL_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../deps/wtl-10.01" CACHE PATH "Pinned unmodified WTL root")
find_path(WTL_INCLUDE_DIR atlapp.h PATHS "${WTL_ROOT}/Include" NO_DEFAULT_PATH REQUIRED)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
get_filename_component(OT_ICON "${CMAKE_CURRENT_SOURCE_DIR}/../../resources/otorrent.ico" ABSOLUTE)
configure_file(resources/MainForm.rc.in "${CMAKE_CURRENT_BINARY_DIR}/MainForm.rc" @ONLY)
add_executable(otorrent-wtl-components WIN32
  src/Main.cpp
  src/Ot.MainForm.h src/Ot.MainForm.cpp
  src/Ot.MainForm.Design.h src/Ot.MainForm.Design.cpp src/Ot.MainForm.Layout.cpp
  src/Ot.TaskController.h src/Ot.TaskController.cpp
  src/components/Ot.Actions.h src/components/Ot.Actions.cpp
  src/components/Ot.CategoryTree.h src/components/Ot.CategoryTree.cpp
  src/components/Ot.TorrentList.h src/components/Ot.TorrentList.cpp
  src/native/Ot.FormWindow.h src/native/Ot.FormWindow.cpp
  ../wtl/src/Ot.DemoModel.cpp ../wtl/src/Ot.DetailsPane.cpp ../wtl/src/Ot.FencePainter.cpp
  "${CMAKE_CURRENT_BINARY_DIR}/MainForm.rc")
target_include_directories(otorrent-wtl-components PRIVATE "${WTL_INCLUDE_DIR}" src ../wtl/src ../wtl/resources)
target_compile_features(otorrent-wtl-components PRIVATE cxx_std_17)
target_compile_definitions(otorrent-wtl-components PRIVATE UNICODE _UNICODE WINVER=0x0601
  _WIN32_WINNT=0x0601 NOMINMAX WIN32_LEAN_AND_MEAN _CRT_SECURE_NO_WARNINGS)
target_compile_options(otorrent-wtl-components PRIVATE /W4 /permissive- /utf-8 /EHsc
  $<$<CONFIG:Release>:/O2> $<$<CONFIG:Release>:/Gy> $<$<CONFIG:Release>:/Gw>)
target_link_options(otorrent-wtl-components PRIVATE /MANIFEST:NO /SUBSYSTEM:WINDOWS,6.01
  $<$<CONFIG:Release>:/OPT:REF> $<$<CONFIG:Release>:/OPT:ICF> $<$<CONFIG:Release>:/INCREMENTAL:NO>)
target_link_libraries(otorrent-wtl-components PRIVATE comctl32 uxtheme ole32)
add_custom_command(TARGET otorrent-wtl-components POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/README.md" "$<TARGET_FILE_DIR:otorrent-wtl-components>/README.md")
