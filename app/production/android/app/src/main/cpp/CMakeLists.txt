cmake_minimum_required(VERSION 3.22.1)
project(nexus_core LANGUAGES C CXX ASM)
add_library(nexus_core SHARED core.cpp)
target_compile_features(nexus_core PRIVATE cxx_std_17)
target_compile_options(nexus_core PRIVATE -Wall -Wextra -Werror)
target_link_libraries(nexus_core PRIVATE vulkan)

# A libc-independent ARM64 ELF entry point, packaged by AGP as a native library.
# It is executed from nativeLibraryDir, never from writable application data.
add_library(nexus_exec_probe SHARED exec_probe.S)
set_target_properties(nexus_exec_probe PROPERTIES LINKER_LANGUAGE C)
target_link_options(nexus_exec_probe PRIVATE -nostdlib -Wl,-e,nexus_probe_entry)
