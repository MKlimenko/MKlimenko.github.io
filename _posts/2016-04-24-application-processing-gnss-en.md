---
layout: post

# The title of your post
title: Application processing in GNSS
lang: en
categories: [english]
tags: [GNSS, C++]
comments: true
---

> Disclaimer: this post is way outdated. I shall write an update as soon as I get some time. That's still ok, but I've found a better solution.

Most modern GNSS receivers share a similar architecture:

1. Antenna & LNA;
2. Front end;
3. Baseband processing;
4. Application processing.

In hardware it's usually implemented as a separate antenna device, front-end IC for down-conversion and primary filtering, ADCs and an ASIC. ASIC consists of multiple (nowadays up to several hundreds!) channels with correlators, heterodynes, NCOs and so on. Also it may or may not contain a general-purpose processor unit, such as ARM or PowerPC. As far as I know, there are no solutions using the x86 (due to license fees or the power requirements, who knows), but I'd love to create a receiver based on an Edison or something like that.

Application processing is a huge field in GNSS development and it's being used for such a things:

1. Locked loops discriminators with feedback to the satellite channels. This is the heart of tracking;
2. Calculating the PVT from the raw pseudoranges and pseudophases
3. Monitoring the GNSS signal integrity and so on

Lately I've been developing a tool for ARM which prepares DSPs to work and launches them. When you have to prepare bare-metal hardware to work almost every time it's required to read/write to some registers, pull some GPIO pins and so on. 

Let's have a look at an abstract SoC. For example, we have 4 ADCs (GPS L1, GLN L1, GPS L2, GLN L2), and we want to start only two of them. Now we go to the manual and read that to enable ADC #1 and #3 we have to take a 32-bit register, and set the first and the third bit in it. 

```cpp
uint32_t* start_adc_ptr = reinterpret_cast<uint32_t*>(0xfff88000);  
start_adc_ptr[0] = 0xA;  
```

Or even worse:

```cpp
*reinterpret_cast<uint32_t*>(0xfff88000) = 0xA;  
```

Why it's bad? Because it's not clear why the hell would I want to write an 0xA at some memory address (Here I'd like to greet my good friend, who is a C# developer and who literally turns grey when I speak about such "unsafe" things).

Is there a way to improve it? Sure, one may add a nice comment, something like this:

```cpp
//ADC start control registers  
uint32_t* start_adc_ptr = reinterpret_cast<uint32_t*>(0xfff88000);   
//Start ADC 1 and 3: 0000_0000_0000_0000_0000_0000_0000_1010 = 0xA  
start_adc_ptr[0] = 0xA;   
```

Well ok, now it's clear and good to create, test and run like there's no tomorrow. This is ok when someone will support your projects in five years time, but it becomes more and more complicated if there's a need to modify or update the code. So you have to add some more bits, somehow convert it to hex value.

The solution is the ```std::bitset``` container. It's used to implement an integer number (or a ```std::string``` like "00001010") as an array of bits. So now if we need to modify our code it's easier to do this way:

```cpp
#include <bitset>  

//ADC start control registers   
uint32_t* start_adc_ptr = reinterpret_cast<uint32_t*>(0xfff88000);    
//Start ADC 1 and 3: 0000_0000_0000_0000_0000_0000_0000_1010 = 0xA  
uint32_t old_value = 0xA;  
std::bitset<32> new_value(old_value);  
new_value[0] = 1;  
new_value[2] = 1;  
//new_value: Start ADC 0..3: 0000_1111  
start_adc_ptr[0] = static_cast<uint32_t>(new_value.to_ulong());   
```

In the code above new_value is initialized with an old value, and then two bits are being set. And that's it. Also this containter extremely simplifies the bitwise programming questions on an interview. new_value.count() returns the number of the bits set, bitwise operations are simplified to the dumbest possible level.

The more I work with C++ the more I get amused by it. And not only by the C++11/14 features (which are great, check out the decltype(auto) functions), but also by the older STL and Boost stuff.