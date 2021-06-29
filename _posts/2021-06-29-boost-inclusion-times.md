---
layout: post
title: Boost libraries inclusion penalty
lang: en
categories: [english]
tags: [C++]
comments: true
---

**TL;DR;** I've made a (yet another) simple [repo](https://github.com/MKlimenko/check_compile_times) and a table on its' [wiki](https://github.com/MKlimenko/check_compile_times/wiki) to estimate the build penalty when including boost headers.

Boost [libraries](https://www.boost.org/) have a mixed reputation in the C++ community. There are a lot of exceptional quality libraries with algorithms and data structures missing in the standard library. One might even say, that the boost is kind of a playground to test something before it can get into the standard (smart pointers are one of the many examples). On the other hand, boost gets heavily criticized for overcomplication, custom build environment and a lot of cross-connections. Don't forget the NIH syndrome, which once forced me to re-implement the `static_vector` class. 

C++ is (in)famous for it's compilation times, especially for the template-heavy code. That got me thinking, how bad is the penalty for including the boost headers? So I've came up with a simple CMake script, which creates a trivial source file with a single `#include` directive, repeated N times for all the main boost headers I could reach:

```CMake
foreach(header ${HEADERS_TO_PROCESS})
  string(REPLACE "." "-" filename_preliminary ${header})
  string(REPLACE "/" "-" header_name ${filename_preliminary})
  set(filename "${CMAKE_CURRENT_LIST_DIR}/${header_name}_main.cpp")
  file(WRITE ${filename} "#include <${header}>\n  int main() { return 0; }\n")
      
  set(executable_name "Check${header_name}")
  add_executable(${executable_name} ${filename})
  target_compile_options(${executable_name} PUBLIC -ftime-trace)
  target_link_libraries(${executable_name} pthread stdc++ stdc++fs)
endforeach()
```

Then I used the `-ftime-trace` clang (9.0+, IIRC) switch to generate JSON report on the compilation times. I decided to settle for the whole `.cpp` compilation time since it's easier to drag it from the report.

Due to the fact, that neither Linux nor Windows are real-time operating systems, compilation times wouldn't be constant and will have some distribution. To account for that, I ran the compilation process several times (10 to 20 looks fine to me) and averaged the results.

I wrote a simple program to read the clang reports, average the values and print them in a markdown-friendly way. I also decided that it would be interesting to estimate the relative slowdown to the plain `int main()` source file. The resulting table looks something like this:

| Header  | Time, ms  | Relative slowdown   |
|-  |-  |-  |
|boost/accumulators/accumulators.hpp  |3000.4 |357.19 |
|boost/algorithm/algorithm.hpp  |693.667  |82.5794  |
|boost/align.hpp  |495.733  |59.0159  |
|...  |...  |...  |

To make it more reproducible and trustworthy, I've added the Travis CI script to build, measure the time and auto-generate and upload to the [wiki](https://github.com/MKlimenko/check_compile_times/wiki). As a rant, I'd like to say that I much prefer the [GitLab](https://mklimenko.github.io/english/2020/02/02/gitlab-ci-cpp/) way of CI, which is much more intuitive to me.

An interesting fact: I've conducted my first runs at my local PC (Ryzen 3700X, 32GB, WSL Ubuntu) and the bare `int main()` took relatively the same time to compile (7.2 vs 8 ms), the time tripled for the heaviest boost files (2100 vs 6600 ms for the boost/geometry.hpp).

There's a simple [repo](https://github.com/MKlimenko/check_compile_times) you may check out, the build dependencies are relatively simple (clang 9+ and boost, however, I encourage you to use ninja for speedup).