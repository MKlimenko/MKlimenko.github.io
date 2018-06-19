---
layout: post
title: Write-only variables
lang: en
categories: [english]
tags: [C++]
comments: true
---

Earlier this week we've had a nice chat with my colleague about an interesting task, which I've found quite entertaining and, most important, a nice interview topic.

In plain C and C++, we use memory-mapped I/O to access registers, which means that every register has a dedicated address by which we can access it. Here's an example of a (partial) memory layout from the documentation.

![memory](/assets/img/write-only/memory.png)

There are basically three types of registers:

* Read-write
* Read-only
* Write-only

There are no problems in defining both read-write and write-only registers via references or pointers, although I'm not a big fan of a bare register access (as I've discussed this [earlier](/english/2018/05/13/a-guide-to-better-embedded/), I prefer to add a couple of layers of indirection to make my code less error-prone):

```cpp
volatile auto &read_write = *reinterpret_cast<std::uint32_t*>(register_address);

const volatile auto &read_only = *reinterpret_cast<std::uint32_t*>(register_address);
```

To make variable read-only we simply add the const-qualifier to the reference declaration. During the discussion of the previous article, a couple of people were puzzled about the ```reinterpret_cast``` part. This operator is the only way to convert address (as a fixed number from the documentation) to the pointer. Via the pointer, we will access the underlying data.

But there is no qualifier in the language to perform the write-only access. And this is where we unleash the true power of the C++: custom types or classes. But before we dive into solving this task, let's measure the initial approach performance. I'll compile the code with the -O2 optimization and -std=c++17 flag:

```cpp
/// Code:
constexpr std::size_t register_address = 123456;
const volatile auto &read_only = *reinterpret_cast<std::uint32_t*>(register_address);


void foo() {
    auto dst = read_only;
}

/// Disassembly:
foo():
  mov eax, DWORD PTR ds:123456
  ret

```

Only two instructions, which is hard to beat, but we're not afraid. Let's take the advantage of the known register address, so we can use ```constexpr``` in our task. First of all, we will declare a class with a private reference. Read and write operations may be implemented as a ```Get()``` and ```Set()``` methods:

```cpp
class Register {
private:
    static volatile inline std::uint32_t &ref = *reinterpret_cast<std::uint32_t*>(register_address);
public:
    static std::uint32_t Get(){
        return ref;
    }

    static void Set(std::uint32_t val){
        ref = val;
    }
};
```

There are a lot of qualifiers for the internal reference, to make it clear:

1. ```static``` makes this reference independent from the structure object
2. ```volatile``` is there to indicate that the value of the reference may change during the program execution and the compiler should not cache it
3. ```inline```. A great C++17 feature, allowing to declare static variables without the need for an external .cpp file. Have you ever tried to initialize a ```std::map``` inside a class? Now you can do it without any additional fuss.

And here's the compiler output:

```cpp
/// Code:
void RegGet() {
    auto dst = Register::Get();
}

void RegSet(std::uint32_t val) {
    Register::Set(val);
}

/// Disassembly:
RegGet():
  mov eax, DWORD PTR ds:123456
  ret
RegSet(unsigned int):
  mov DWORD PTR ds:123456, edi
  ret
```

Exactly the same disassembly and performance, yay! Although, there might be a problem with an old codebase you'll try to update because it is quite difficult to search and replace all of the assignments to the ```Get()``` methods. I don't know any C++ refactoring tool which is capable of doing such a thing, and, most importantly, I even have no idea how one might be implemented. 

To solve this we will add a couple of overloads to our class:

1. Assignment operator for the write operations
2. ```std::uint32_t``` casting operator for the read operations
3. ```T``` casting operator to raise a compile-time error when you try to read register into some type other than ```std::uint32_t```

```cpp
class Register {
// ...
    Register& operator=(std::uint32_t val){
        ref = val;
        return *this;
    }

    template <typename T>
    operator T() const{
        static_assert(std::is_same_v<T, std::uint32_t>, "You should assign this register to the std::uint32_t value"); 
        return T();
    }

    operator std::uint32_t() const {
        return ref;
    }
} reg;
```

Since the assignment and casting operators cannot be static, we have to create an object of our class to use it:

```cpp
/// Code
void RegAssign() {
    std::uint32_t dst = reg;
}

void RegGetCast(std::uint32_t val) {
    reg = val;
}

/// Disassembly:
RegAssign():
  mov eax, DWORD PTR ds:123456
  ret
RegGetCast(unsigned int):
  mov DWORD PTR ds:123456, edi
  ret
```

And we still get the same performance with the familiar syntax! There is one more tweak we should do to make this class ready for use: get rid of the hard-coded address in the reference. Bear in mind, that we should make it compile-time friendly. This may be done with the help of the templates. A couple of changes:

```cpp
template <std::size_t address> 
class Register {
private:
    static volatile inline std::uint32_t &ref = *reinterpret_cast<std::uint32_t*>(address);
//...
};

Register<register_address> reg;
```

And we're done for today. You may fiddle with the code [here](https://godbolt.org/g/fyZYzD). It really looks to me like a nice little task to chat about.