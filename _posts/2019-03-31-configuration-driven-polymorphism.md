---
layout: post
title: Configuration-driven polymorphism
lang: en
categories: [english]
tags: [C++]
comments: true
---

Today I'd like to share with you a technique I've been working on for some time now. It is called a configuration-driven polymorphism (CDP) and may be used to create a chain of function calls with different signatures during the run-time via reading some arbitrary configuration file.

> TL;DR: CDP allows you to wrap your API in a way to allow other programmers to rearrange the functions in the variety of ways. You may give neural network primitives to the data scientists to let them test their new approaches and hypothesis. You may decide what's better: distortion into the compressor or vice versa. 

## Motivation

A couple of weeks ago I've been watching for a great talk by Pavel Filonov from the Kaspersky Lab called [Learning in Python, evaluating in C++](https://www.youtube.com/watch?v=-AsZPAfV93Q) (unfortunately, no English subtitles). To paraphrase it in a couple of sentences, it is dedicated to the building the process of interaction between the data scientists, which are responsible for creating various machine-learning-based approaches and the C++ programmers, who implement it in the production.

And it got me thinking: what if we've got a library of primitives (third-party or self-made), which may be composed into something more high-level in terms of arranging those primitives without the need to recompile the code (and installing the whole developer environment on every computer). 

As a result, we'd like to see something like this:

```cpp
void foo() {
    ChainProcessing c("..\\..\\..\\xml\\example.xml");
    std::vector<double> data_vec{ 0.1, -0.1, 0.2, -0.2 };
    auto dst = c.Process(std::move(data_vec));
    // some kind of visitor
}
```

## Main idea

To achieve some flexibility, we'll wrap every function into a class, with an overloaded `operator()` and some data fields. This is required to unify the calling interface since the only changing parameter during the call-time will be the input data. We have a (simplified) virtual base class to address it:

```cpp
template <typename InputContainer, bool keep_previous = false>
class CommonProcessing {
public:
    using InitializationTypes = std::variant<
        // possible argument types
    >;
    using InputOutputTypes = std::variant<
        // possible operator() and return types
    >;

    virtual InputOutputTypes operator()(const InputOutputTypes& src) = 0;
    virtual InputOutputTypes operator()(InputOutputTypes&& src) = 0;
    virtual std::unique_ptr<CommonProcessing> Clone() const = 0;
    virtual std::unique_ptr<CommonProcessing> Clone(InitializationTypes&& values) const = 0;
    virtual InitializationTypes ReadParameters(tinyxml2::XMLElement* root) const = 0;
    virtual ~CommonProcessing() = default;
};
```

You might notice several common approaches in the code:

1. Polymorphic copy via the `Clone()` method, which is implemented in the derived classes and returns the `std::unique_ptr` to the base class;
2. Input and output of the `operator()` have the same type, which is an alias for the `std::variant` of all the possible types of the functions you've decided to add to the CDP. Note, that there is currently no checking if the types are valid, it will throw an exception during the evaluation.

There is an another helper macro (yup, I know, but there is no better way) in that header file:

```cpp
#define CALLWRAPPER \
virtual InputOutputTypes operator()(const InputOutputTypes& src) override { \
    auto input = std::get<ProcessInput>(src); \
    return Process(input); \
} \
virtual InputOutputTypes operator()(InputOutputTypes&& src) override { \
    if constexpr (keep_previous) { \
        auto laundered_src = std::get<ProcessInput>(std::move(src)); \
        auto dst = Process(laundered_src); \
        src = std::move(laundered_src); \
        return dst; \
    } \
    else \
        return Process(std::get<ProcessInput>(std::move(src))); \
}
```

It provides the implementation of the virtual `operator()` for the derived classes, gets the actual value from the `std::variant` and calls the internal `Process()` method, which wraps an API function. Let's take a look at the wrapper itself:

```cpp
#pragma once

#include "CommonProcessing.hpp"

template <typename InputContainer, bool keep_previous = false>
class Accumulator final : public CommonProcessing <InputContainer, keep_previous> {
public:
    using BaseType = CommonProcessing<InputContainer, keep_previous>;
    using InitializationTypes = typename BaseType::InitializationTypes;
    using InputOutputTypes = typename BaseType::InputOutputTypes;
    using ProcessInput = InputContainer;
    using ProcessOutput = typename InputContainer::value_type;

private:
    ProcessOutput Process(const ProcessInput& src) {
        return std::accumulate(src.begin(), src.end(), ProcessOutput());
    }

    ProcessOutput Process(ProcessInput&& src) {
        return Process(src);
    }

    virtual std::unique_ptr<BaseType> Clone(InitializationTypes&& values) const override {
        return std::unique_ptr<BaseType>(new Accumulator());
    }
    
public:
    virtual std::unique_ptr<BaseType> Clone() const override {
        return std::unique_ptr<BaseType>(new Accumulator());
    }

    virtual InitializationTypes ReadParameters(tinyxml2::XMLElement* root) const {
        return InitializationTypes{};
    }

    CALLWRAPPER
};
```

This is a wrapper for the `std::accumulate` algorithm, which returns the sum of the container. We declare some helping aliases, which improve readability and implement all of the `CommonProcessing` interface. Note the `CALLWRAPPER` macro from above and that there is no parameters to this function. Here's an example of the `ReadParameters` from an another class:

```cpp
template <typename InputContainer, bool keep_previous = false>
class Multiplier final : public CommonProcessing <InputContainer, keep_previous> {
public:
    // ...
    using InitInput = std::tuple<typename InputContainer::value_type, typename InputContainer::value_type>;

    InitInput value;

    // ...

    virtual InitializationTypes ReadParameters(tinyxml2::XMLElement* root) const {
        InitInput dst{};
        auto& first = std::get<0>(dst);
        auto& second = std::get<1>(dst);

        auto ptr = root->FirstChildElement();
        first = folly::to<typename InputContainer::value_type>(BaseType::ReadString(ptr));
        ptr = ptr->NextSiblingElement();
        second = folly::to<typename InputContainer::value_type>(BaseType::ReadString(ptr));

        return dst;
    }

    // ...
};
```

Stay with me, there's only a couple of things left to discuss. One more helper class, actually.

Once we've created a wrapper for all the functions you want to provide, our goal is to combine them. Let me provide the code first and we'll discuss it afterwards.

```cpp
#include "CommonProcessing.hpp"
//#include all the other functions

#define NAMEOF(x) #x

template <typename InputContainer = std::vector<double>, bool keep_previous = false>
class ChainProcessing final {
private:
    using BaseProcessing = CommonProcessing<InputContainer, keep_previous>;
    using FunctionEntryTemplate = FunctionEntry<typename BaseProcessing::InitializationTypes>;

    std::vector<std::unique_ptr<BaseProcessing>> processing_vector;
    std::vector<typename CommonProcessing<InputContainer>::InputOutputTypes> results_vector;

    // should be constexpr
    static auto GetMap() {
        std::unordered_map<std::string, std::unique_ptr<BaseProcessing>> map;
        map.emplace(NAMEOF(Multiplier),             new Multiplier<InputContainer, keep_previous>{});
        map.emplace(NAMEOF(Accumulator),            new Accumulator<InputContainer, keep_previous>{});
        map.emplace(NAMEOF(InverseSign),            new InverseSign<InputContainer, keep_previous>{});
        map.emplace(NAMEOF(ElementwiseMultiplier),  new ElementwiseMultiplier<InputContainer, keep_previous>{});
        map.emplace(NAMEOF(Placeholder),            new Placeholder<InputContainer, keep_previous>{});

        return map;
    }

    void InitializeProcessingVector(
        std::vector<FunctionEntryTemplate>&& read_functions,
        const std::unordered_map<std::string, std::unique_ptr<BaseProcessing>>& function_map
    ) {
        processing_vector.clear();
        for (auto&read_function : read_functions)
            if (!read_function)
                processing_vector.emplace_back(function_map.at(read_function)->Clone());
            else
                processing_vector.emplace_back(function_map.at(read_function)->Clone(std::move(read_function)));

        if constexpr (keep_previous) 
            results_vector.reserve(processing_vector.size() + 1); // + input
    }

public:
    ChainProcessing(const std::string& config_path) {
        static auto function_map = GetMap();
        auto read_functions = FunctionEntryTemplate::ReadConfiguration(config_path, function_map);
        InitializeProcessingVector(std::move(read_functions), function_map);
    }

    auto Process(InputContainer src) {
        if constexpr (keep_previous) {
            results_vector.clear();
            results_vector.emplace_back(std::move(src));
            for (auto&& function_ptr : processing_vector) {
                auto& function = *function_ptr;
                results_vector.emplace_back(function(results_vector.back()));
            }

            return std::move(results_vector);
        }
        else {
            typename CommonProcessing<InputContainer>::InputOutputTypes dst = std::move(src);

            for (auto&& function_ptr : processing_vector) {
                auto& function = *function_ptr;
                dst = function(std::move(dst));
            }

            return dst;
        }
    }
};
```

This class requires some breaking in pieces. 

`GetMap()` method creates a map of the pointers to the base class, which are accessible via the names of the derived classes. I've used a simple NAMEOF macro, which does the job just fine.

A constructor of the class:

1. Gets this map (which should be evaluated at the compile-time, but it would be available only with the C++20 and the `constexpr std::string`);
2. Reads the configuration and fills the vector of the `FunctionEntry` helper class objects;
3. Creates the vector of base classes with the filled parameters (remember the polymorphic copy? This is where we need one).

Voila, we're ready to go. Now we just call the `Process` method, which iterates over the processing vector and calls the derived `operator()`. In the end, we're getting the result in another `std::variant`, but a simple visitor will be able to retrieve it and do whatever we want.

The configuration will look like this, but it's always up to you and the format you're most familiar with:

```xml
<Configuration>
    <Function>
        <Name>Multiplier</Name>
        <Parameters>
            <Parameter>-0.001</Parameter>
            <Parameter>8e-6</Parameter>
        </Parameters>
    </Function>
    <Function>
        <Name>ElementwiseMultiplier</Name>
        <Parameters>
            <Parameter>
                <value>1</value>
                <value>2</value>
                <value>3</value>
                <value>4</value>
            </Parameter>
        </Parameters>
    </Function>
    <Function>
        <Name>Accumulator</Name>
    </Function>
    <Function>
        <Name>InverseSign</Name>
    </Function>
</Configuration>
```


## Comparison with the handwritten chain of functions

Since we're C++ programmers, we care about possible performance penalties, induced by this approach. There are two major downsides that I can think of:

1. A lot of boilerplate code currently has to be written by the programmer. It is pretty typical, so I hope I'll find a way to wrap it up nicely, but now it's a bit error-prone.
2. Several layers of indirection, which may interfere with the optimizer. My benchmarks show a negligible difference, but it should be noted. 

In my opinion, it is a fair price to pay for such flexibility. You're always welcome to check out the code at my [GitHub](https://github.com/MKlimenko/ConfigurationDrivenPolymorphism) and tell me, where I'm wrong.