---
layout: post
title: std::embed for the poor (C++17), or cross-platform resource storage inside the executable
lang: en
categories: [english]
tags: [C++]
comments: true
---

Embedding custom resources inside an executable has always been a pain for the C++ developers. There are several options to perform such operation:

1. Manual integration. Works relatively well with text resources, almost impossible to work with binary ones.
2. Various preprocessing tools, the most popular one is the `xxd`. This is a de-facto standard tool for such a job but has several drawbacks (path collisions amongst them).
3. Using the linker. It works but the code becomes extremely ugly in my opinion.

**TL;DR**: I've made an `embed.exe` tool which allows managing arbitrary resources efficiently before we have the `std::embed`. Check it out in the [repo](https://github.com/MKlimenko/embed)

- [Overview](#overview)
- [Tool structure](#tool-structure)
    - [Preprocessing](#preprocessing)
    - [Usage](#usage)
- [Questions and shortcomings:](#questions-and-shortcomings)
    - [Why not `constexpr`?](#why-not-constexpr)
    - [Why resource is represented in a decimal way, not hexadecimal?](#why-resource-is-represented-in-a-decimal-way-not-hexadecimal)
    - [How bad my build times will become?](#how-bad-my-build-times-will-become)
    - [Can I use it?](#can-i-use-it)
    - [What else can be done?](#what-else-can-be-done)

## Overview

There's a [proposal](https://wg21.link/p1040) to allow compile-time resource integration, which addresses all of those approaches. I really like the proposal, but the downside is that we won't be able to see it before the C++2b (2023?).

To substitute `std::embed` with the current standard I've made a little pre-build tool with the following syntax during the build:

```
embed.exe [input files and/or folders] [-o output]
```

And in the application itself:

```cpp
#include "resource_holder.hpp"

int main() {
    auto data = rh::embed("G:\\test.bin");

    return 0;
}
```

## Tool structure

Since we're not able to modify the compiler (and there's no reason to do so), there are two steps:

1. Reading and converting files into the compiler-friendly way (preprocessing)
2. Usage inside the user application

### Preprocessing

`embed.exe` gets a list of files and folders as an input parameter and path to the projects' source directory as an output.

For every file the tool creates header file with unique filename: `resource_(filename_hash).hpp`. `filename_hash` is being calculated by the `std::filesystem::hash_value`.

Every processed resource has the following structure:

```cpp
#pragma once

#include "..\resource_holder.hpp"

namespace { 
    const std::array<std::uint8_t, 12> resource_3133233769538895004 {
        72,101,108,108,111,32,116,104,101,114,101,33,
    };
    const auto resource_3133233769538895004_path = R"(G:\test.txt)";
}
```

After all the resources have been converted, two additional helper headers are created: `span.hpp` because it's not standard yet and `resource.hpp`, which is a simple wrapper for the above `std::array` and path:

```cpp
class Resource {
public:
    template <typename T>
    using span = tcb::span<T>;
    using EmbeddedData = span<const std::uint8_t>;

private:
    const EmbeddedData arr_view;
    const std::string_view path_view;

public:
    template <typename Container>
    Resource(const Container& arr, std::string_view path) : arr_view(arr), path_view(path) {}

    auto GetArray() const {
        return arr_view;
    }

    auto GetPath() const {
        return path_view;
    }
};
```

The main class is called `ResourceHolder`. There's also a global variable `embed`, which is used to simulate the upcoming `std::embed`. Let me list the current version of the `ResourceHolder` and then we'll discuss it:

```cpp
#pragma once

#include "resource.hpp"
#include "embedded_resources\\resource_3133233769538895004.hpp"

class ResourceHolder {
private:
    const inline static std::array resources {
        Resource(resource_3133233769538895004,    resource_3133233769538895004_path),
    };

public:
    [[nodiscard]]
    static auto Gather(std::string_view file) {
        auto it = std::find_if(resources.begin(), resources.end(), [file](const auto& lhs) {
            return lhs.GetPath() == file;
        });
        if (it == resources.end())
            throw std::runtime_error("Unable to detect resource with name " + std::string(file));

        return it->GetArray();
    }

    [[nodiscard]]
    static auto ListFiles() {
        std::vector<std::string_view> dst{};
        dst.reserve(resources.size());
        for (auto&el : resources)
            dst.push_back(el.GetPath());

        return dst;
    }

    [[nodiscard]]
    static auto FindByFilename(std::string_view file) {
        std::vector<Resource> dst{};
        dst.reserve(resources.size());
        auto sought_file = std::filesystem::path(file).filename();
        std::copy_if(resources.begin(), resources.end(), std::back_inserter(dst), [sought_file](const auto &item) {
            return sought_file == std::filesystem::path(item.GetPath()).filename();
        });
        
        return dst;
    }

    auto operator()(std::string_view file) {
        return Gather(file);
    }
};

namespace rh {
    ResourceHolder embed;
}
```

First of all, we include all of the preprocessed resources and create an internal `static std::array` with all the binary arrays and paths. The most important method here is `Gather()`, which searches all of the resources for the filename and returns non-owning array (`span`) for the corresponding one. To make things easier, I've overloaded the `operator()` to make interactions with the global object easier.

### Usage

After we've integrated everything the only thing left to do is to include the helper `resource_handler.hpp` header and gather the embedded data. I've also implemented a couple of methods that may be useful, but aren't in the proposal and will hardly ever become standard, such as get list of all resources and find all the files with the same filename. Apart from that, `rh::embed` provides exactly the same interface, as the proposed `std::embed`.

```cpp
auto data = rh::embed("G:\\test.bin");
```

## Questions and shortcomings:

### Why not `constexpr`?

Perfectly legit question, as the `std::embed` in the proposal is performing everything in the compile-time. When I started working on this project I wanted it to be `constexpr`. Everything went smoothly with small files, but I've encountered a problem when I tried to embed the 2 MB executable:

> error C2131: expression did not evaluate to a constant

The point is that, most probably, the compiler has run out of steps. To create the `constexpr` array compiler has to iterate over every element and verify that it is constant. Unfortunately, it's hard to do with millions of elements. Technically, nothing prevents from using it in the compile-time environment, but we're not there yet.

### Why resource is represented in a decimal way, not hexadecimal?

Resource headers aren't meant to be read by humans, so there's no way to perform xxd-style formatting. In addition, decimal values may have 1 to 3 digits (most probably 2), hexadecimal has 3 to 4 due to the "0x" prefix (3.5). With that little optimization, we are able to shrink the resource header size for about 30-50%.

### How bad my build times will become?

Not as bad as you may think. I've profiled the `embed.exe` and the biggest bottleneck is the hard drive I/O. There is a noticeable increase in the linking time, but unfortunately, there's nothing I can do about it.

### Can I use it?

Sure thing, here's the [repo](https://github.com/MKlimenko/embed). There are a couple more things I need to fiddle with, but it is mostly ready.

### What else can be done?
One of the things I want to do is make `embed.exe` work with clang AST. The point is to scan all of the source files, get filenames and work with them. It'll make `embed.exe` less prone to errors like forgetting to add the resource to the pre-build step.