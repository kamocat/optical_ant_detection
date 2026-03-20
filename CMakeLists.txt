cmake_minimum_required(VERSION 3.16)
project(count_ants_cpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(OpenCV REQUIRED)
find_package(yaml-cpp REQUIRED)

add_executable(count_ants count_ants.cpp)
target_link_libraries(count_ants PRIVATE ${OpenCV_LIBS} yaml-cpp)