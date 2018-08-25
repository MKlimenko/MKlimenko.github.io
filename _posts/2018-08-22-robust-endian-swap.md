---
layout: post
title: Robust endianness conversion
lang: en
categories: [english]
tags: [C++]
comments: true
---

>
>**UPD:** As Shafik Yaghmour has pointed out, the solution below is an undefined behaviour, due to the use of an inactive member of the union. Another solution is using the fact, that we are allowed by the standard to cast pointers to `char (std::int8_t)` and `unsigned char (std::uint8_t)`. So we get rid of pointers, fill an array of bytes, reverse it and copy the data back to the user. Here's the [link](https://godbolt.org/z/j8LHmC) to play with.
>

When we're dealing with binary protocols there's always a question about the order of bytes. Often embedded devices have big-endian and Intel-based PC's utilize little-endian. To illustrate it, let's visualize how the 0x11223344 `std::uint32_t` value lies in the memory:

| Byte offset       | 3        | 2        | 1        | 0        |
|---------------    |------    |------    |------    |------    |
| Little-endian     | 0x11     | 0x22     | 0x33     | 0x44     |
| Big-endian        | 0x44     | 0x33     | 0x22     | 0x11     |

Our job is to reverse the order of bytes when there is an endianness mismatch. There is a popular approach and the one I'm about to suggest, which is more robust and less error-prone.

## Classical endianness conversion

There are two classical approaches, which StackOverflow suggests: binary shifts and intrinsics-based, none of which I fancy.

### Binary shifts

We can construct the new value by masking the value to extract the byte and shifting it to the corresponding place, which is pretty trivial for the 16-bit values:

```cpp
void SwapBinary(std::uint16_t &value) {
    value = (value >> 8) | (value << 8);
}
```

Things get a bit more complicated when we would want to process 32-bit values:

```cpp
void SwapBinary(std::uint32_t &value) {
    std::uint32_t tmp = ((value << 8) & 0xFF00FF00) | ((value >> 8) & 0xFF00FF);
    value = (tmp << 16) | (tmp >> 16);
}
```

And for the 64-bit ones:

```cpp
void SwapBinary(std::uint64_t &value) {
    value = ((value & 0x00000000FFFFFFFFull) << 32) | ((value & 0xFFFFFFFF00000000ull) >> 32);
    value = ((value & 0x0000FFFF0000FFFFull) << 16) | ((value & 0xFFFF0000FFFF0000ull) >> 16);
    value = ((value & 0x00FF00FF00FF00FFull) << 8)  | ((value & 0xFF00FF00FF00FF00ull) >> 8);
}
```

There is also the need to sometimes swap endianness of an array, so we're dealing with a lot of functions. 

### Intrinsics

Another suggested way is to use intrinsics. I'm not a big fan ot this approach because of the portability reasons, but there is such a way:

```cpp
// MSVC:
#include <intrin.h>
unsigned short _byteswap_ushort(unsigned short value);
unsigned long _byteswap_ulong(unsigned long value);
unsigned __int64 _byteswap_uint64(unsigned __int64 value);

// GCC:
int32_t __builtin_bswap32 (int32_t x)
int64_t __builtin_bswap64 (int64_t x)
```

## Robust endianness swap

Both of the methods above are very error-prone and we can make a unified solution, which will have the same performance, but which will be much more efficient in terms of development and support cost.

The idea is simple: we define a template function, in which there is a union, containing both the passed value and the `std::array` of the corresponding size. We create two objects of such union and perform the reverse copying from one to another. All the extra assignments will be optimized out by the compiler, which will make this code fast and efficient.

```cpp
template <typename T>
void SwapEndian(T &val) {
    union U {
        T val;
        std::array<std::uint8_t, sizeof(T)> raw;
    } src, dst;

    src.val = val;
    std::reverse_copy(src.raw.begin(), src.raw.end(), dst.raw.begin());
    val = dst.val;
}
```

There is also a SFINAE-d version, if you would like to make sure you won't pass anything wrong:

```cpp
template <typename T>
void SwapEndian(T &val, typename std::enable_if<std::is_arithmetic<T>::value, std::nullptr_t>::type = nullptr);
```

The good thing about this is that we have a template for all the corner cases and possible types. But the greatest is that the compiler [was able](https://godbolt.org/z/bVyRzh) to optimize both of these functions into one assembly command `bswap`. Some instructions sets haven't got that command and if this will become the bottleneck of your program, you can make a template specialization for the case you need and have a well-oiled and working common case, just like this:

```cpp
template <typename T>
void SwapEndian(T &val) {
    union U {
        T val;
        std::array<std::uint8_t, sizeof(T)> raw;
    } src, dst;

    src.val = val;
    std::reverse_copy(src.raw.begin(), src.raw.end(), dst.raw.begin());
    val = dst.val;
}

template<>
void SwapEndian<std::uint32_t>(std::uint32_t &value) {
    std::uint32_t tmp = ((value << 8) & 0xFF00FF00) | ((value >> 8) & 0xFF00FF);
    value = (tmp << 16) | (tmp >> 16);
}
```