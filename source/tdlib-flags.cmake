# Options of libtdjni.so, after those of td/example/android

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
