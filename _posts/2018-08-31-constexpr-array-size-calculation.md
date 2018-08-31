---
layout: post
title: constexpr array size calculation
lang: en
categories: [english]
tags: [C++]
comments: true
---

I was writing an article about adding `constexpr` to some legacy code generation function when I found myself explaining one feature so detailed I decided to extract it into the separate article.

## Basic version

Imagine we have some class, which is responsible for generating an array of data. Simplified code looks like [this](https://godbolt.org/z/-bm-mf):

```cpp
#include <cstdint>
#include <vector>

class Foo {
private:
    std::size_t array_size_seed = 0;

    auto GetArraySize() {
        return array_size_seed * 2;
    }

public:
    Foo(std::size_t val) : array_size_seed(val){}

    auto GetVector() {
        std::vector<int> dst(GetArraySize());
        for(std::size_t i = 0; i < dst.size(); ++i)
            dst[i] = i * 5;

        return dst;        
    }
} foo(12);
```

Both the size calculation and array filling are simplified since they're not that important.

## First attempt to `constexpr`

In the current (C++17) standard there is no such thing as the `constexpr std::vector<T>`, but there is a `std::array<T, size>`. Let's add `constexpr` to everything:

```cpp
#include <array>
#include <cstdint>
#include <vector>

class Foo {
private:
    std::size_t array_size_seed = 0;

    constexpr auto GetArraySize() const {
        return array_size_seed * 2;
    }

public:
    constexpr Foo(std::size_t val) : array_size_seed(val){}

    constexpr auto GetArray() {
        std::array<int, GetArraySize()> dst{};
        for(std::size_t i = 0; i < dst.size(); ++i)
            dst[i] = i * 5;

        return dst;        
    }
};
```

There is, however, a drawback: this won't [compile](https://godbolt.org/z/Wvh3JE). According to the standard, `constexpr` functions may be called both at the compile- and runtime. Therefore, arguments of the functions (`this` pointer in that case) are not constant, so `std::array` size cannot be resolved at the compile-time. 

As I've mentioned earlier, there is a proposal for the `constexpr!` specifier, which forces calculations to be compile-time only. If we've had it, we'd be done by now.

To make this work we need to force the calculations to be compile-time. Hopefully, there's a way to make this: templates.

## Force `constexpr` with templates

There's a so-called "non-type template parameters" feature, which we'll be using here. The thing is that with templates you're not limited only to `template <typename T>`, you can also pass integral or enumeration values, references etc.

```cpp
#include <array>
#include <cstdint>
#include <vector>

class Foo {
private:
    std::size_t array_size_seed = 0;

    constexpr auto GetArraySize() const {
        return array_size_seed * 2;
    }

public:
    constexpr Foo(std::size_t val) : array_size_seed(val){}

    template <const Foo& foo>        // <-----
    constexpr static auto GetArray() {
        std::array<int, foo.GetArraySize()> dst{};
        for(std::size_t i = 0; i < dst.size(); ++i)
            dst[i] = i * 5;

        return dst;        
    }
};
```

Notice, that we've made the method static and get the object via a template. One of the good things is that the standard allows static class methods to access the private members of the same class (notice the `foo.GetArraySize()`, which is declared `private`). 

With that said and done we can create an object during the compile time and generate a variable-size array with its methods.

```cpp
constexpr Foo foo(12);
constexpr auto arr = Foo::GetArray<foo>();
```

Just take a look at the disassembly [here](https://godbolt.org/z/AtLEYW)!
