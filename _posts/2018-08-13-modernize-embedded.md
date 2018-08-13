---
layout: post
title: Modern C++ in the embedded world
lang: en
categories: [english]
tags: [C++, GNSS]
comments: true
---

A lot has been said and done about modern (post-2011) C++. Most of the times it makes your code more expressive, which often leads to better optimizations from the compiler. As you may know, I'm currently working on a triple-band GNSS receiver, which is built upon the BBP2 SoC. This SoC has two NeuroMatrix DSPs and one ARM1176JZF-S core. NeuroMatrix has a very old toolchain, even pre-standardization era (~1995). ARM compiler toolkit is built upon some GCC version with C++11 core language support, but no library support.

This is a very depressing situation for 2018, but since there is no way to get a newer compiler toolchain, we have to make our job with the existing tools. During the work on the receiver, I've encountered several features, I miss the most, which I will present here. 

## Extended `constexpr`

Early (C++11) `constexpr` with one-line return statements was a great feature, but with very limited practical use, encouraging recursion debugging. C++14 allowed multi-line `constexpr` functions. 

In the practical applications, `constexpr` may be used to generate various tables to reduce the initialization time at the beginning of the application. One of the important features in the GNSS receiver is the time to first fix (TTFF), which will greatly suffer if the receiver will evaluate everything in the runtime.

To bypass the lack of `constexpr` I had to add another step to the build process, which compiles and runs a PC-based code generation program. For example, it generates this code:

```cpp
#ifndef _SPACING_CORRECTION_HPP
#define _SPACING_CORRECTION_HPP

/// CORB spacing correction. Required due to the digital nature of the CORB in BBP2. L(L)_spacing = arr[E(E)_spacing]
namespace spacing_correction {

    unsigned int gps_l1_l2[] = {
        0,    2,    4,    4,    6,    6,    8,    8,    10,    10,    12,    12,    14,    14,    16,    16,    18,    18,    20,    20,    22,    22,    24,    24,    26,    26,    28,    28,    30,    30,    32,    32,    34,    34,    36,    36,    38,    38,    40,    40,    42,    42,    44,    44,    46,    46,    48,    48,    50,    50,    52,    52,    54,    54,    56,    56,    58,    58,    60,    60,    62,    62,    62,    62,    
    };

    unsigned int gln_l1_l2[] = {
        0,    2,    3,    4,    5,    6,    7,    8,    9,    10,    11,    12,    13,    14,    15,    16,    17,    18,    19,    20,    21,    22,    23,    24,    25,    26,    27,    28,    29,    30,    31,    32,    33,    34,    35,    36,    37,    38,    39,    40,    41,    42,    43,    44,    45,    46,    47,    48,    49,    50,    51,    52,    53,    54,    55,    56,    57,    58,    59,    61,    62,    63,    63,    63,    
    };

    unsigned int gps_gln_l3_l5[] = {
        0,    10,    10,    10,    10,    10,    10,    10,    10,    10,    20,    20,    20,    20,    20,    20,    20,    20,    20,    20,    30,    30,    30,    30,    30,    30,    30,    30,    30,    30,    40,    40,    40,    40,    40,    40,    40,    40,    40,    40,    50,    50,    50,    50,    50,    50,    50,    50,    50,    50,    60,    60,    60,    60,    60,    60,    60,    60,    60,    60,    60,    60,    60,    60,    
    };

}

#endif

```

We can see that those are relatively small arrays, perfect for the `constexpr`.

## `auto`

I'm a big fan of AAA (almost always auto) principle. It makes your code clearer and more readable. In the multi-processor environments, you often have to construct a reference from the object address:

```cpp
volatile some_namespace::StructName& object_reference = *reinterpret_cast<volatile some_namespace::StructName*>(some_namespace::object_address);
```

This can be simplified to the following, since the `auto&` preserves the cv-qualifiers:

```cpp
auto& object_reference = *reinterpret_cast<volatile some_namespace::StructName*>(some_namespace::object_address);
```

Moreover, since there are many times when we need to construct an object from the address we can create a function for this (which will be optimized out anyway):

```cpp
template <typename T>
constexpr auto& ToReference(std::size_t address) {
    // volatile T* because object may be edited outside of the program scope
    return *reinterpret_cast<volatile T*>(address);
}

auto& object_reference = ToReference<some_namespace::StructName>(some_namespace::object_address);
```

## `std::array<>`

Many people who I've been talking to tend to underestimate the `std::array<>` usefulness. That it's nothing more than a plain C array. There are, however several advantages over the regular arrays:

1. `std::array<>` has a value semantics, which means it's possible to return it from the function;
2. `std::array<>` has a `size()` method;
3. `std::array<>` has STL-interface, friendly with algorithms.

## Strongly typed `enum`s

No discussion here, just hell of a lot of mistakes I see here and there in the code that prefers to use plain `enum`s over the `enum class`.

## P.S.

That is, pretty much it. Of course, I miss some of the methods, C++11 has introduced (my personal favourite is the `data()`), but those a not as important in my everyday code as the things I've listed above.
