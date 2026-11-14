cmake_minimum_required(VERSION 3.24)
project(OnlyTorrentQtPrototype LANGUAGES CXX RC)
if(NOT MSVC OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "Use an MSVC x64 Qt kit for comparison with the WTL prototype")
endif()
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC_SEARCH_PATHS "${CMAKE_CURRENT_SOURCE_DIR}/ui")
# Dynamic Qt kits use /MD. Do not mix them with the WTL prototype's static CRT.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
find_package(Qt6 6.5 REQUIRED COMPONENTS Widgets)
get_filename_component(OT_ICON "${CMAKE_CURRENT_SOURCE_DIR}/../../resources/otorrent.ico" ABSOLUTE)
configure_file(resources/Prototype.rc.in "${CMAKE_CURRENT_BINARY_DIR}/Prototype.rc" @ONLY)
qt_add_executable(otorrent-qt-prototype WIN32
  src/Main.cpp
  src/Ot.QtMainWindow.h src/Ot.QtMainWindow.cpp
  src/Ot.QtTaskModel.h src/Ot.QtTaskModel.cpp
  src/Ot.QtFenceDelegate.h src/Ot.QtFenceDelegate.cpp
  ui/OtMainWindow.ui resources/Prototype.qrc
  ../wtl/src/Ot.DemoModel.h ../wtl/src/Ot.DemoModel.cpp
  "${CMAKE_CURRENT_BINARY_DIR}/Prototype.rc")
target_include_directories(otorrent-qt-prototype PRIVATE src ../wtl/src)
target_compile_definitions(otorrent-qt-prototype PRIVATE UNICODE _UNICODE NOMINMAX WIN32_LEAN_AND_MEAN)
target_compile_options(otorrent-qt-prototype PRIVATE /W4 /permissive- /utf-8 /EHsc
  $<$<CONFIG:Release>:/O2> $<$<CONFIG:Release>:/Gy> $<$<CONFIG:Release>:/Gw>)
target_link_options(otorrent-qt-prototype PRIVATE /MANIFEST:NO
  $<$<CONFIG:Release>:/OPT:REF> $<$<CONFIG:Release>:/OPT:ICF> $<$<CONFIG:Release>:/INCREMENTAL:NO>)
target_link_libraries(otorrent-qt-prototype PRIVATE Qt6::Widgets)
add_custom_command(TARGET otorrent-qt-prototype POST_BUILD
  COMMAND "${CMAKE_COMMAND}" -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/README.md" "$<TARGET_FILE_DIR:otorrent-qt-prototype>/README.md")
