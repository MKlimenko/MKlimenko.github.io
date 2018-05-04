---
layout: post
title: Importance of assembly
lang: en
categories: [english]
tags: [C++]
comments: true
---

C++11 has introduced an extremely important and useful feature: strongly typed enumerators. I will not recap all of the useful features; there are many articles about that. In addition, its 2018, so you better be using them. 

One of the good things about ```enum class```es is the ability to choose the underlying type (or `enum base`, as it's often called). It goes like this:

```cpp
enum class Foo : std::uint32_t {
    a = 0,
    b,
    c,
};
```

It is important in some compilers, which are not quite conformal to the standard. I have encountered this problem with the ARM Compiler 5. We have a GNSS SoC with two NeuroMatrix cores (NMC) and one ARM1176JZF-S called [BBP2 (link in russian, sorry)](https://www.module.ru/catalog/micro/sbis_k1888vs18/). NMC is a pretty good as DSP, but has a 32-bit byte.

>The byte is a unit of digital information that most commonly consists of eight bits. ... it is the _smallest addressable unit_ of memory in many computer architectures.[Wiki](https://en.wikipedia.org/wiki/Byte).

The smallest addressable unit of the NMC memory is 32 bits (4 bytes in terms of ARM). That means that if we are about to write 8 bits into the internal memory, it will crash, which can lead to nasty bugs to find.

A simple example to illustrate the case: we have to perform some inter-processor communications via shared memory. One of the best ways to do it is to place an object of a structure in some place with fixed address, so both processors could access it. Moreover, let us have a function, which will change the state of the enum:

```cpp
enum class Foo {
    a = 0,
    b,
    c,
};

struct Bar {
    Foo foo = Foo::a;
} bar;

void Meow() {
    bar.foo = Foo::b;
}
```

Somewhy it is not working. One can understand it, after a brief look at the generated assembly:

```assembly
_Z4Meowv PROC
    MOV      r0,#1
    LDR      r1,|L0.52|
    STRB     r0,[r1,#0]  ; bar // <-------
    BX       lr
    ENDP
```

Woops, `STRB` instruction. If you're not familiar with the ARM assembly, `STRB` stands for store byte [(doc)](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.dui0802a/STRB_reg.html). As I have said earlier, it will crash.

Let us change the underlying type of the enum, according to the one in the beginning of the article:

```assembly
_Z4Meowv PROC
    MOV      r0,#1
    LDR      r1,|L0.52|
    STR      r0,[r1,#0]  ; bar // <-------
    BX       lr
    ENDP
```

Yay! No more crashing. However, what if we are stuck with a pre-C++11 compiler and plain enums? It seems to me that there is only one way: introduce a dummy identifier with a value that will extend the limits to the 32-bit integer:

```cpp
enum OldFoo {
    a = 0,
    b,
    c,
    dummy = INT_MAX
};
```

By the way, this just may be a bug in the ARM Compiler 5, since the standard is solid on this one:

> For a scoped enumeration type, the underlying type is int if it is not explicit ly specified (ISO/ IEC 14882 :2017(E), 10.2.5)

Moreover, no other compilers suffer from this issue (number 123 is used for better view):

x86-64 GCC trunk:
```assembly
_Z4Meowv:
    mov DWORD PTR bar[rip], 123
    nop
    ret
```

x86-64 clang trunk:
```assembly
Meow(): # @Meow()
    push rbp
    mov rbp, rsp
    mov dword ptr [bar], 123
    pop rbp
    ret
```

x86-64 icc 18.0.0:
```assembly
Meow():
    push rbp #13.13
    mov rbp, rsp #13.13
    mov DWORD PTR bar[rip], 123 #14.2
    leave #15.1
    ret #15.1
```

Link to the compiler explorer is [here](https://godbolt.org/g/2s11M6). 

In conclusion, I hope I've managed to convince you, that this is kind of bugs and errors, which are easily spotted with reading the assembly.