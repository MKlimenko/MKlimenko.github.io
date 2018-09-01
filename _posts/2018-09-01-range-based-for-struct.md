---
layout: post
title: Range-based for over a struct object
lang: en
categories: [english]
tags: [C++]
comments: true
---

One of the things that I miss the most in the C++ is the ability to iterate over every single field in the POD (plain old data) structure. A basic example from the top of my head is when you need to preprocess the data, received with the different byte endianness (big vs little endian).

## What would I want to see

C++11 has introduced an extremely useful construction called range-based for loop. It is great if you only care to perform some actions on every element of the container:

```cpp
std::vector<int> vec { 5, 4, 3, 2, 1, };

for(auto &el: vec)
    Process(el);
```

The case is why aren't we allowed to do the following?

```cpp
struct {
    std::uint32_t fw_version = 0;
    std::uint16_t sector_0_version = 0;
    std::string id = "";
    std::array<std::uint8_t, 6> options{};
} data;

for (auto &el: data)
    Process(el);
```

## Current language status (C++17)

We're encountering a problem here: latest standard (C++17) doesn't allow this. Well, if your class is some sort of a container with the values of the same type, you can implement `begin()` and `end()`, but it is impossible for the heterogeneous structures like the one above.

Unfortunately, the only way to iterate over every element of the structure is to write it yourself:

```cpp
struct {
    std::uint32_t fw_version = 0;
    std::uint16_t sector_0_version = 0;
    std::string id = "";
    std::array<std::uint8_t, 6> options{};

    void Process() {
        Process(fw_version);
        Process(sector_0_version);
        Process(id);
        Process(options);
    }
} data;

data.Process();
```

I think you'll agree with me that it's awful. Every time you change the structure you have to remember to update the `Process()` method.

There is, however, a solution: static reflection. This isn't ([yet](http://wg21.link/p0194r3)) part of the language, but we already have some libraries to perform similar kind of tasks. In my opinion, most promising are magic_get by Antony Polukhin (may be included in the `boost` as the `boost::pfr` library) and tinyrefl by Manu Sánchez. Since I wasn't able to build tinyrefl for the Visual Studio, I'll focus on the magic_get.

## Using the compile-time static reflection

With the magic_get library our code transforms into this:

```cpp
struct {
    std::uint32_t fw_version = 0;
    std::uint16_t sector_0_version = 0;
    std::string id = "";
    std::array<std::uint8_t, 6> options{};
} data;

boost::pfr::for_each_field(std::forward<decltype(data)>(data), [](auto&& val) { 
    Process(val); 
});
```

I agree it's not as pretty as the code I wanted to work but imagine my happiness when I was able to get rid of all the boilerplate code I had to write earlier. And since everything is resolved at the compile-time there is no performance penalty.

If you ever had any similar task, [check out](https://github.com/apolukhin/magic_get) this library, it may help you a lot.
