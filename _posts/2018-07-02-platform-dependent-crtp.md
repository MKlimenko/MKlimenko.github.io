---
layout: post
title: CRTP-based platform-dependent optimizations
lang: en
categories: [english]
tags: [C++]
comments: true
---

One of the main reasons to choose C++ over any other programming language is performance. Eventually, this is what we're being paid for. There are several cases when we have to write multi-platform:

1. Programs for both Linux and Windows. Here we have to deal with different standard conformance among the compilers (which is much better nowadays), WinAPI vs POSIX etc;
2. Applications for targets with different instruction sets (SSE vs AVX, for example).
3. The one that I deal the most with on my day-to-day basis: applications for heterogeneous systems, which is a very fancy way to name a processor with cores of various architectures. This is the one I'll be focusing on this article, but others are pretty much the same.

Key for the effective software is code reuse, which we should try to achieve with this article. Below I'll provide an example of the ultimate code reuse when the parts you don't want won't even compile (which is good, especially for code with library functions), explain it and babble on about some other stuff.

- [An introduction](#an-introduction)
- [Platform-dependent optimizations](#platform-dependent-optimizations)
- [Empowering the CRTP](#empowering-the-crtp)
- [Limiting the compilation](#limiting-the-compilation)
- [Conclusion](#conclusion)

> TL;DR CRTP is great for compile-time code selection, check out [this](https://github.com/MKlimenko/PlatformDependentCRTP) github repo and [this](https://godbolt.org/g/57mU4G) compiler explorer simplified sandbox.

## An introduction

CRTP stands for the curiously recurring template pattern. It is a C++ idiom which provides compile-time polymorphism, where you have a templated base class and a derived class, which inherits from the base with itself as a template parameter:

```cpp
template<typename T>
class Base { // ...
};

class Derived : public Base<Derived> { // ...
};
```

This idiom is well-known and has been discussed a lot, so we won't stop to look at the details. The key thing here is that the templates are being deduced at the compile-time, which is exactly what we need.

## Platform-dependent optimizations

There is an excellent library out there called Intel Integrated Performance Primitives (IPP). It has a ton of functions for signal and image processing, from the very basics (memory allocation, copying, filling etc) up to the complex algorithms, such as digital filtering, compression and LTE MIMO MMSE Estimation (I have absolutely no clue what this is, but sounds awesome, isn't it? :)

The key thing about this library is that it's being made by the Intel itself (by their division in the Nizhniy Novgorod), and it utilizes every single per cent of the processors' computational resources. The first time I've tried it I was astonished. I don't like is the plain C interface and strange deprecation policy, but those are the things we can ignore for such quality of the product.

Now the programming part. Let's say, that we have to generate a `std::vector` filled with $$ sin(x) $$ samples. We can implement it in 'common' C++ and with IPP:

```cpp
// Common
auto GenerateSine(double frequency, double sampling_rate, std::size_t samples) {
    std::vector<double> dst(samples);
    const double pi_2 = 8.0 * std::atan(1.0);
    for (std::size_t i = 0; i < dst.size(); ++i) {
        double triarg = i * pi_2 * frequency / sampling_rate;
        dst[i] = cos(triarg);
    }
    return dst;
}

// IPP
auto GenerateSine(double frequency, double sampling_rate, std::size_t samples) {
    std::vector<double> dst(samples);
    double phase = 0;
    ippsTone_64f(dst.data(), static_cast<int>(dst.size()), 1.0, frequency / sampling_rate, &phase, IppHintAlgorithm::ippAlgHintNone);
    return dst;
}
```

Yup, I know about the interface. But trust me, the performance gain is really worth it. And our job, as a programmer, to write an abstraction layer above it to hide the implementation details.

## Empowering the CRTP

Let's assume, that we develop our application for three targets:

1. Intel (IPP) for the sake of the optimization 
2. arm (NEON) for an example of compile-time rejection
3. All of the others

For the CRTP we have to write the base class, which will define the interface. All of the application-specific classes will inherit from the interface and implement it. I prefer to split those into separate headers, but it's all up to you.

```cpp
// Interface.hpp
template <typename T>
struct Interface {
    static void foo() {
        return T::foo(); // Just to make things clearer in the compiler explorer
    }

    static auto GenerateSine(double frequency, double sampling_rate, std::size_t samples) {
        return T::GenerateSine(frequency, sampling_rate, samples);
    }
};
// end of Interface.hpp
```

Then there's time to implement it. I won't be providing the arm implementation, hope you can forgive me since it's not important:

```cpp
// Intel.hpp
struct Intel : Interface<Intel> {
    static void foo() {
        volatile auto a = 789456;
    }
    
    static auto GenerateSine(double frequency, double sampling_rate, std::size_t samples) {
        std::vector<double> dst(samples);
        double phase = 0;
        ippsTone_64f(dst.data(), static_cast<int>(dst.size()), 1.0, frequency / sampling_rate, &phase, IppHintAlgorithm::ippAlgHintNone);
        return dst;
    }
};
// end of Intel.hpp

// Common.hpp
struct Common : Interface<Common> {
    static void foo() {
        volatile auto a = 123456;
    }

    static auto GenerateSine(double frequency, double sampling_rate, std::size_t samples) {
        std::vector<double> dst(samples);
        const double pi_2 = 8.0 * std::atan(1.0);
        for (std::size_t i = 0; i < dst.size(); ++i) {
            double triarg = i * pi_2 * frequency / sampling_rate;
            dst[i] = cos(triarg);
        }
        return dst;
    }
};
// end of Common.hpp
```

## Limiting the compilation

Unfortunately, there are things which can be done only by using macros. I'm not fond of this solution, feel free to contact me and propose a better one.

We can detect the target processor by checking the predefined variables set by the compiler. There are lists of them in the compiler's documentation, check for the ones used in your compiler. Here we check for the predefined variable, and, if it's defined, we let our code to be compiled and define a temporary type variable. This is used only because there is no way to redefine the `typedef` or the `using` alias.

```cpp
// Intel.hpp

#if defined(__x86_64__) || defined(__i386__) || \
    defined(_M_X64) || defined(_M_IX86)

struct Intel : Interface<Intel> { // ... 
};

#define temp_processor Intel
#endif

// end of Intel.hpp

// arm.hpp
#if defined(__arm__) || defined(_M_ARM) || \
    defined(_M_ARM64)

struct arm : Interface<arm> { // ... 
};

#define temp_processor arm
#endif
// end of arm.hpp
```

The last bit is done in the `Common.hpp`: we check for the available implementations (if the `temp_processor` has been defined), create an alias for the most optimized version and another one to access it via CRTP:

```cpp
// Common.hpp
struct Common : Interface<Common> { // ... 
};

#if defined (temp_processor)
using processor = temp_processor;
#undef temp_processor
#else
using processor = Common;
#endif

template <typename T = processor>
using DSP = Interface<T>;
// end of Common.hpp
```

And we're done! Now we simply use methods from the `DSP` in our code and get the best performance on every target platform:

```cpp
void Generate() {
    auto dst = DSP<>::GenerateSine(1e3, 1e6, 1000);
}
```

DSP is a templated alias for a reason: we might wanna ensure, that the optimized version works correctly. That's when we need to compare the output of the optimized and the `Common` versions:

```cpp
bool Test() {
    auto dst = DSP<>::GenerateSine(1e3, 1e6, 1000);
    auto dst_common = DSP<Common>::GenerateSine(1e3, 1e6, 1000);

    return dst == dst_common;
}
```

## Conclusion

To make CRTP practical we've done the following:

* Decided upon the interface
* Implemented that interface for every target platform we've got
* Limited the compilation of the unsuitable derivatives by the preprocessor
* Selected the most appropriate one and made it the default one
* Made optimizations easy to check
* Celebrate the fact that our cross-platform/cross-architecture/cross-instruction set applications share the same interface.

Once again, there's a link to [the](https://godbolt.org/g/57mU4G) compiler explorer simplified sandbox and the [github repo](https://github.com/MKlimenko/PlatformDependentCRTP) to fiddle with. 