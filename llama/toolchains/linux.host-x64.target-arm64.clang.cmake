set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER clang)
set(CMAKE_CXX_COMPILER clang++)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} --target=aarch64-linux-gnu")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} --target=aarch64-linux-gnu")
