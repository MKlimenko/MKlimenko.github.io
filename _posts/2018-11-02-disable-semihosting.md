---
layout: post
title: Disable semihosting with ARM Compiler 5/6
lang: en
categories: [english]
tags: [C++]
comments: true
---

I can certainly say that most people underestimate the importance of the I/O for their applications, especially during the development phase. It's always handy to write and read something to the console, file etc. Gladly, there's a thing within the ARM toolchain to do that called semihosting.

Semihosting is a set of low-level primitives which allows the target application to interact with host I/O facilities (hence the *semi*-hosting). There's a great image by ARM:

![Diagram](http://www.keil.com/support/man/docs/armcc/armcc_pge1464343202279.png)

Every time a program invokes any I/O there's a supervisor call exception, which is handled by the debugger (semihosting server) on the host side. 

There are two drawbacks with this approach:
1. When the processor is in the supervisor mode, the user application is halted and waits for execution to finish. This is unacceptable for real-time applications. 
2. With no debugger (standalone applications loaded via EDCL or from the ROM), there is no semihosting server. Every call to the I/O function will result in a crash. Unfortunately, during the initialization of the program, there's always a call to the server, which means your program will always crash.

However, there is a way to disable the semihosting completely. Eventually, I've ended up with a static library I'm linking with the standalone versions of my applications.

First of all, you have to add the `__use_no_semihosting` symbol to the source file. This is made differently in ARM Compiler 5 (GCC 4.8.3-based) and ARM Compiler 6 (LLVM-based). To differentiate them I'm using the `__ARMCC_VERSION` macro:

```cpp
#if __ARMCC_VERSION >= 6000000
    __asm(".global __use_no_semihosting");
#elif __ARMCC_VERSION >= 5000000
    #pragma import(__use_no_semihosting)
#else
    #error Unsupported compiler
#endif
```

Then we have to reimplement the I/O-dependent library functions:

```cpp
#include <rt_sys.h>
#include <rt_misc.h>
#include <time.h>

const char __stdin_name[] =  ":tt";
const char __stdout_name[] =  ":tt";
const char __stderr_name[] =  ":tt";

FILEHANDLE _sys_open(const char *name, int openmode){
    return 1;
}

int _sys_close(FILEHANDLE fh){
    return 0;
}

char *_sys_command_string(char *cmd, int len){
    return NULL;
}

int _sys_write(FILEHANDLE fh, const unsigned char *buf, unsigned len, int mode){
    return 0;
}

int _sys_read(FILEHANDLE fh, unsigned char *buf, unsigned len, int mode){
    return -1;
}

void _ttywrch(int ch){
}

int _sys_istty(FILEHANDLE fh){
    return 0;
}

int _sys_seek(FILEHANDLE fh, long pos){
    return -1;
}

long _sys_flen(FILEHANDLE fh){
    return -1;
}

void _sys_exit(int return_code) {
    while (1)
        ;
}

clock_t clock(void){
    clock_t tmp;
    return tmp;
}

void _clock_init(void){
}

time_t time(time_t *timer){
    time_t tmp;
    return tmp;
}

int system(const char *string){
    return 0;
}

char *getenv(const char *name){
    return NULL;
}

void _getenv_init(void){
}
```

And that's it. Build a library with all those dummies and you're good to go.

There are two things worth mentioning. Due to lack of semihosting, you have to allocate space for the heap and the stack by yourself, which can be made via the scatter file (`ld`-script alternative for the ARM compilers). Therefore, you must supply the scatter-loading for the standalone applications.

Another thing is that you should always build this library for the same target as your application. For example, if your program doesn't require any floating point operations, you may use the generic ARM instructions. Otherwise, you might want to use the floating-point coprocessor (VFP) and compile your programs with the corresponding settings.