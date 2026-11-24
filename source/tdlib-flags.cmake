# Options of libtdjni.so, after those of td/example/android

# Arm is built by a profile of the app's starts, chats, search and pushes: what they run is compiled for speed, the rest
# for size. Clang of the legacy NDK can't read the profiles
if (ANDROID_ABI MATCHES "^(arm64-v8a|armeabi-v7a)$" AND CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 21)
  set(TDLIB_PROFILE "${CMAKE_CURRENT_LIST_DIR}/build/profiles/${ANDROID_ABI}.profdata")
  add_compile_options(
    $<$<COMPILE_LANGUAGE:CXX>:-O2>
    $<$<COMPILE_LANGUAGE:CXX>:-flto=full>
    $<$<COMPILE_LANGUAGE:CXX>:-fvisibility=hidden>
    $<$<COMPILE_LANGUAGE:CXX>:-fvisibility-inlines-hidden>
    $<$<COMPILE_LANGUAGE:CXX>:-fprofile-use=${TDLIB_PROFILE}>
    # Names of static functions in the profile have no folder of the build
    "$<$<COMPILE_LANGUAGE:CXX>:SHELL:-mllvm -static-func-full-module-prefix=false>"
    "$<$<COMPILE_LANGUAGE:CXX>:SHELL:-mllvm -disable-preinline>"
    "$<$<COMPILE_LANGUAGE:CXX>:SHELL:-mllvm -pgo-cold-func-opt=minsize>"
    "$<$<COMPILE_LANGUAGE:CXX>:SHELL:-mllvm -profile-summary-cutoff-cold=999000>"
  )
  add_link_options(
    -flto=full
    -Wl,-mllvm,-profile-summary-cutoff-cold=999000
    -Wl,--bp-compression-sort=function
    -Wl,--call-graph-profile-sort=none
  )
  return()
endif()

add_compile_options(
  $<$<COMPILE_LANGUAGE:CXX>:-flto=full>
  $<$<COMPILE_LANGUAGE:CXX>:-fvisibility=hidden>
  $<$<COMPILE_LANGUAGE:CXX>:-fvisibility-inlines-hidden>
)
add_link_options(-flto=full -Wl,-O2)

function(tgx_optimize_hot_libraries)
  foreach(target tdutils tdactor tdnet tddb tdmtproto tdapi)
    target_compile_options(${target} PRIVATE $<$<COMPILE_LANGUAGE:CXX>:-O2>)
  endforeach()
endfunction()
cmake_language(DEFER CALL tgx_optimize_hot_libraries)
