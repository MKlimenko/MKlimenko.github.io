---
layout: post
title: Embed resources in C++ on Windows (Visual Studio)
lang: en
categories: [english]
tags: [C++]
comments: true
---

I've got a confession to make: I love standalone applications. Nothing buggers me more than getting a "DLL missing" error from an executable you've got from somewhere. Another problem is when an application requires some external data. Sometimes those files should be placed in relative directories alongside the executable, in the most disturbing case the paths are hardcoded. 

The DLL hell may be resolved by linking with the static libraries (`/MT` switch instead of the `/MD`), and there is a solution for external files: resources.

This is a brief compilation of resource usage in Visual Studio, which might be useful for Windows developers.

> N.B. AFAIK, there are ways in Linux to perform a similar task (google `objcopy`). 
>
> Also, one can write a custom application to create `.hpp`-file with an array of bytes. This is a fine solution which I've used a couple of times in embedded environments.

Resource files are binary data used in the application. Usually, resources are used to hold icons, bitmaps, toolbars etc. I have used this approach to create a project generator for our SoC family. Based on the SoC itself and type of loader I've recovered and placed corresponding files in the requested folder.

Our job is to store information in the executable, recall it in the runtime and somehow use it. There is a proposal for the `std::embed`, but we have a job to do and can't wait for it to be added.

## Placing the data into the executable

As I've mentioned earlier, we'll be using the resource mechanism, provided by the Visual Studio. Steps to embed arbitrary data:

0. Get your files ready. Sounds easy, but just make sure of it, okay?
1. Create `resource.h` and a resource-definition script `$(ProjectName).rc`.
2. Pass the script to the resource compiler
3. Link the compiled resources with the rest of the executable

Most of the stuff is handled by the Visual Studio, which is quite helping. However, you should be aware of two minor drawbacks:

1. Visual Studio generates absolute paths in the `.rc`-files, which is not computer-agnostic. For example, I have my projects stored on the E:\ drive, and my colleague stores his projects on the D:\ drive. The project structure is the same, but it won't build.
2. Windows and thereafter Visual Studio doesn't recognize files with extension only (like `.gitignore`). Instead of normal processing, Visual Studio creates a binary file and copies the full content. To mitigate this issue we'll have to edit the `.rc`-file manually.

Alright, now let's inspect the generated files:

### `resource.h`

```cpp
//{{NO_DEPENDENCIES}}
// Microsoft Visual C++ generated include file.
// Used by EmbedResources.rc
//
#define IDR_TEXT1                       101
#define IDR_TEXT2                       102

// Next default values for new objects
// 
#ifdef APSTUDIO_INVOKED
#ifndef APSTUDIO_READONLY_SYMBOLS
#define _APS_NEXT_RESOURCE_VALUE        103
#define _APS_NEXT_COMMAND_VALUE         40001
#define _APS_NEXT_CONTROL_VALUE         1001
#define _APS_NEXT_SYMED_VALUE           101
#endif
#endif
```

`{{NO_DEPENDENCIES}}` is an internal comment for the compiler to ignore the changes in the `resource.h` so that your dependent source files won't recompile. 

The file starts by the defines with the according to the structure: `IDR_$(ResourceType)$(NumberOfResource)`. The numbers themselves are incremental. The following block of defines serves the purpose of tracking those numbers for various types of resources.

### `$(ProjectName).rc`

```cpp
#include "resource.h"

IDR_TEXT1               TEXT                    "..\\..\\..\\resources\\very_important_data.txt"
IDR_TEXT2               TEXT                    "..\\..\\..\\resources\\more_data.txt"
```

Here I've provided the simplified version of the resource script to avoid ambiguity. First of all, we have to include the application-specific `resource.h` file, which we've just discussed.

Following lines contain all the resources you want to embed in the following manner: `$(ResourceID)` `$(ResourceClass)` `$(ResourceAddress)`

## Restoring the data at runtime

There are three magic WinAPI functions we're going to use: `FindResource()`, `LoadResource()` and `LockResource()`. Also one shouldn't forget to `FreeResource()` after you've done. This isn't critical if you're certain that the resource will be acquired only once. In a similar matter, compiler never deallocates memory.

Such procedure is calling for the RAII pattern, let's make one:

```cpp
class Resource {
public:
    struct Parameters {
        std::size_t size_bytes = 0;
        void* ptr = nullptr;
    };

private:
    HRSRC hResource = nullptr;
    HGLOBAL hMemory = nullptr;

    Parameters p;

public:
    Resource(int resource_id, const std::string &resource_class) {
        hResource = FindResource(nullptr, MAKEINTRESOURCEA(resource_id), resource_class.c_str());
        hMemory = LoadResource(nullptr, hResource);

        p.size_bytes = SizeofResource(nullptr, hResource);
        p.ptr = LockResource(hMemory);
    }
};
```

The most interesting part here is the constructor, where all the acquisition is performed.

First of all, by passing `NULL` to the `GetModuleHandle()` we acquire the descriptor of the current module (process). `FindResource()` function determines the location of a resource with `resource_id` type and `resource_class name` in the module that has created the current process. If there is such a resource, the function will return the corresponding handle, `NULL` otherwise.

`LoadResource()` retrieves a handle, which may be converted to a pointer (`void*`, since there is no type information at this point) by the `LockResource()` function. `SizeofResource()` returns the number of bytes of the resource. 

The best way to handle the existing data is to use a non-owning array, something like `std::span`, but it's only C++20. If your resources aren't that big and you can give some extra memory, wrap it into `std::vector<T>` and work the way your API is designed. Here I'll use `std::string_view`, as a non-owning string.

```cpp
class Resource {
/// ...
    auto GetResourceString() const {
        std::string_view dst;
        if (p.ptr != nullptr)
            dst = std::string_view(reinterpret_cast<char*>(p.ptr), p.size_bytes);
        return dst;
    }
};

/// ...
void GetFile() {
    Resource very_important(IDR_TEXT1, "TEXT");
    auto dst = very_important.GetResourceString();
}
```

And we're done. You may do whatever you want with this data: process it, save it to the hard drive etc. Here's the project, if you want to play and have fun with [it](https://github.com/MKlimenko/EmbedResources).