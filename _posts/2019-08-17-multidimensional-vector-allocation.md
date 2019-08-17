---
layout: post
title: Multidimensional vector allocation
lang: en
categories: [english]
tags: [C++]
comments: true
---

This week we've had a little C++-related chat with my colleague. One of our projects required an allocation of deeply nested `std::vector`. Something like this: `std::vector<std::vector<std::vector<int>>>`. My colleague asked if there's a way to initialize the vector without the for loops.

Here's the initial code he's been working with:

```cpp
std::vector<std::vector<std::vector<int>>> vec;

vec.resize(height);
for (int i = 0; i < height; ++i) {
    vec[i].resize(width);
    for (int j = 0; j < width; ++j)
        vec[i][j].resize(depth);
}
```

That's not what I'd call pretty. It's working, but it is easy to make a mistake and something inside of me yells that it can be done better.

My first thought was constructors to the rescue!

```cpp
std::vector<std::vector<std::vector<int>>> b(
    height, std::vector<std::vector<int>>(
    width, std::vector<int>(
    depth)
    )
);
```

It is better, but too verbose. Because of the `std::initializer_list` constructor it is impossible to pass the dimensions to the "count-value" constructor.

Another thought has visited my head, that our compile times weren't long enough and we need some Alexandrescu-inspired staff. Let me list the code and explain it (you can fiddle with it on the [compiler explorer](https://godbolt.org/z/gbCPLs) as usual).

```cpp
#include <iostream>
#include <vector>

namespace detail {
    template<typename T, std::size_t sz>
    struct vector_type {
        using type = std::vector<typename vector_type<T, sz - 1>::type>;
    };
    template<typename T>
    struct vector_type<T, 1> {
        using type = T;
    };

    template<typename T, std::size_t sz>
    using vector_type_t = typename vector_type<T, sz>::type;
}

template <typename T>
struct VectorGenerator {
    static auto Generate(std::size_t last_arg) { 
        return std::vector<T>(last_arg);
    }

    template <typename ...Args>
    static auto Generate(std::size_t first_arg, Args... args) {
        using vector = std::vector<typename detail::vector_type_t<T, 1 + sizeof...(args)>>;

        return vector(first_arg, VectorGenerator<T>::Generate(args...));
    }
};

int main() {
    auto b = VectorGenerator<int>::Generate(1, 2, 3, 4, 5, 6, 7, 8); 
    std::cout << b.size() << ", ";
    std::cout << b[0].size() << ", ";
    std::cout << b[0][0].size() << ", ";
    std::cout << b[0][0][0].size() << ", ";
    std::cout << b[0][0][0][0].size() << ", ";
    std::cout << b[0][0][0][0][0].size() << ", ";
    std::cout << b[0][0][0][0][0][0].size() << ", ";
    std::cout << b[0][0][0][0][0][0][0].size();

    return 0;
}
```

The `detail` namespace has a helper `vector_type` class, which represents the N-dimensional vector of type `T`. Unfortunately, it is forbidden by the standard to partially specialize the type alias, which is why I've introduced this little struct.

The `VectorGenerator` is a small class, that wraps the generation methods. The `Generate` method calls the `std::vector` constructor and passes the `first_arg` as a size, and a recursive `Generate` to provide the allocated sub-vectors. When we're done iterating, create the simple `std::vector<T>` with `last_arg` elements and unwrap the call stack.

Because of the parameter packs, we're able to detect the number of arguments and generate the `std::vector` of the according size. We've had no need to provide the non-default initialized vectors, so I haven't provided such possibility, but it is possible to do so with the non-type template parameter for the trivial types. And trust me, you don't want to create N-dimensional vector for the non-trivial ones.

Thank you for visiting, hope you've enjoyed this little article. It is possible to create an N-dimensional array in such manner with the only difference that the dimensions should be provided via the non-type template parameters to force the compile-time evaluation (before we have the `consteval`).