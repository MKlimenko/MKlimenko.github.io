---
layout: post
title: Embedding data into a function with lambdas
lang: en
categories: [english]
tags: [C++]
comments: true
---

**TL;DR**: using `data = std::move(some_data)` in the lambda capture may allow you to build some good abstractions for your code with no performance penalty. 

Lambdas are great for several reasons, among them is the ability to raise the level of indirection. For example, one may compose lambda from several functions called together:

```cpp
auto composed = [&foo] {
    foo.recall();
    foo.do_something();
    foo.do_something_else();
    foo.save();
};
```

Another thing is that you can keep data inside the lambda. One of the most common patterns I've seen is to keep the object copy with the capture to reuse it:

```cpp
auto keep_pre_cpp17 = [foo = *this] {
    // do something
    foo.MethodCall();
};

auto keep = [*this] {
    // do something
    MethodCall();
};
```

Two things worth pointing out here:

1. Since C++17 it is legal to capture just `*this` without assigning it to the dummy variable. 
2. The object is being copied, therefore making a sort of a snapshot of the object state. Be careful about capturing references, because objects may go out of scope prior to the lambda call.

With that said and done there's nothing preventing us from capturing arbitrary values from the scope. This kind of task appeared when I was wrapping an Ethernet-based bare-metal loader (EDCL). The idea was to prepare all the data and just give a simple `SetupDevice()` function to the user with all the data embedded.

```cpp
struct MemoryRegion { // Prototype
    std::vector<std::uint8_t> image{};
    std::size_t address{};
};

auto GetFunction(EDCL& edcl) {
    // Fill the MemoryRegion (Binary image data + address)
    std::vector<MemoryRegion> data = GetData();

    return [data = std::move(data)] {
        for(auto& el: data)
            edcl.write(el.image, el.address);
    };     
}
```

By `data = std::move(data)` we avoid excess copying and move assign the `data` vector to the capture of the lambda. The returned lambda may be used in two ways:

```cpp
GetFunction(edcl)();

// or

auto prepare_device = GetFunction(edcl);
// ... some initialization work for the host part
prepare_device();
```

