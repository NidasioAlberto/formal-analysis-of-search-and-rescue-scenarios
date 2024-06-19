cmake_minimum_required(VERSION 3.16)

project(Visualizer CXX)

add_subdirectory(curlpp)
add_subdirectory(nlohmann_json)

add_library(visualizer SHARED visualizer.cpp)
target_link_libraries(visualizer curlpp nlohmann_json::nlohmann_json)
