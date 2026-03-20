cmake_minimum_required(VERSION 3.16)
project(count_ants_cpp LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(OpenCV REQUIRED COMPONENTS core imgproc imgcodecs)
find_package(yaml-cpp REQUIRED)

add_executable(count_ants count_ants.cpp)

target_link_libraries(count_ants PRIVATE ${OpenCV_LIBS})

if(TARGET yaml-cpp::yaml-cpp)
    target_link_libraries(count_ants PRIVATE yaml-cpp::yaml-cpp)
elseif(TARGET yaml-cpp)
    target_link_libraries(count_ants PRIVATE yaml-cpp)
else()
    if(DEFINED YAML_CPP_INCLUDE_DIR)
        target_include_directories(count_ants PRIVATE ${YAML_CPP_INCLUDE_DIR})
    endif()
    if(DEFINED YAML_CPP_LIBRARIES)
        target_link_libraries(count_ants PRIVATE ${YAML_CPP_LIBRARIES})
    elseif(DEFINED YAML_CPP_LIBRARY)
        target_link_libraries(count_ants PRIVATE ${YAML_CPP_LIBRARY})
    else()
        message(FATAL_ERROR "yaml-cpp was found but no usable target/library was exposed")
    endif()
endif()
