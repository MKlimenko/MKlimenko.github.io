---
# Posts need to have the `post` layout
layout: post

# The title of your post
title: Beidou (Compass) NH-code

# (Optional) Write a short (~150 characters) description of each blog post.
# This description is used to preview the page on search engines, social media, etc.
#description: >
#  Beidou data bit synchronization with Neuman-Hoffman overlay code

# (Optional) Link to an image that represents your blog post.
# The aspect ratio should be ~16:9.
image: /assets/img/beidou_signal_structure.png

# You can hide the description and/or image from the output
# (only visible to search engines) by setting:
# hide_description: true
# hide_image: true
lang: en

# (Optional) Each post can have zero or more categories, and zero or more tags.
# The difference is that categories will be part of the URL, while tags will not.
# E.g. the URL of this post is <site.baseurl>/hydejack/2017/11/23/example-content/
categories: [english]
tags: [GNSS, C++]
# If you want a category or tag to have its own page,
# check out `_featured_categories` and `_featured_tags` respectively.
---

Beidou signal is pretty similar to the GPS C/A L1 signal [[src]](http://www2.unb.ca/gge/Resources/beidou_icd_english_ver2.0.pdf).

It is CDMA, and the carrier is being modulated via BPSK with the next binary sequences:

1. Ranging code with the chip rate of 2.046 Mchips/s;
2. Navigational message which is modulated on the carrier at 50 bps;
3. Additional 20-bit long Neuman-Hoffman code (NH-code) with the 1000 bps rate

![Signal structure](/assets/img/beidou_nh/signal_structure.png)

Carrier with the first two sequences is (if you mind the chip rate) like the GPS C/A L1 signal. To get the GLONASS L1 signal you just need to add the square wave signal with the 10 ms period.

So why adding the NH-code? It is explained to assist the navigation message symbol synchronization in the receiver as well as the additional spectrum spreading. 

Our goal is to remove the modulation caused by this code. When the signal is relatively strong, there is no problem: the receiver just saves the 20 bits from the PLL output, then compares it with the shifted bit mask, and, if it matches, yay, we've found it!

```cpp
uint64_t NH_code = 0x72B20;  
uint64_t input = 0xB208D;  
for (uint64_t shift = 0; shift < 20; ++shift){  
  //...  
  //Generate shifted code  
   if(shifted_code == input){  
    return shift;  
   }            
}  
```

Looks pretty great and obvious, isn't it? It's fast (I mean really fast), it's very low on the memory consumption and, the most important, it's simple. Easy to understand, easy to support.

But it doesn't cover two very important cases:
Change of the sign of the navigational message bit;
PLL errors due to the low SNR.
If we want to stick with the bitwise algorithm, these cases will give us some serious headache. Taking the possibility of the sign change into account immediately makes the algorithm more complicated, because we have to compare the input not with one mask, but with four for every shift!

And the second case makes it even worse. We can no longer rely on the ```if (shifted_code == input)``` condition. Now the receiver on every step has to write (memory consumption, remember?) the difference betweed the input and the shifted code. Four times for every sign combination. 

That's not very efficient. That's why I propose the correlation-base algorith. It takes 30 bits (seconds) from the PLL, then generates 20-bit long output and searches for the max value. The position of the maximum is the shift, and the sign of it is the sign of the navigational message bit. It looks something like this:

```cpp
 #include <cstdint>  
 #include <cmath>  
 namespace {  
      void MatchedFilter1ms(const int16_t *src, size_t src_len,   
           const int16_t *stretched_code, size_t stretched_code_len, int16_t *dst){  
           for (size_t i = 0; i < src_len; ++i) {  
                dst[i] = 0;  
                for (size_t j = 0; j < stretched_code_len; j++)  
                     dst[i] += stretched_code[j] * src[(i + j) % src_len];  
           }  
      }  
 }  
 void main() {  
      MatchedFilter1ms(src, SAMPLES, NH_code, NH_SAMPLES, matched);  
      for (size_t el = 0; el < SAMPLES; ++el){  
           if (abs(matched[el]) > max){  
                max = abs(matched[el]);  
                imax = el;  
           }  
      }  
      int16_t sign = matched[imax] > 0 ? 1 : -1;  
}  
```

It uses more memory, which is not what you always want on a embedded systems, but it's sligtly faster with -O2, and much, MUCH, more reliable, as you can see below.

![Probability](/assets/img/beidou_nh/probability.png)

That's it for now. There are still some opportunities to improve this algorithm, but I'm happy with it for now. Also, as far as I know, the truncated NH-code (only 10 bits long) is going to be used in the GLONASS L3 signal. With minor changes this code may be used for it.