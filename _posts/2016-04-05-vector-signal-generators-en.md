---
# Posts need to have the `post` layout
layout: post

# The title of your post
title: Vector signal generators

# (Optional) Write a short (~150 characters) description of each blog post.
# This description is used to preview the page on search engines, social media, etc.
#description: >
#  Beidou data bit synchronization with Neuman-Hoffman overlay code

# (Optional) Link to an image that represents your blog post.
# The aspect ratio should be ~16:9.
image: /assets/img/vector_signal_generator/n5182.jpg

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

Long story short: modern RF devices are awesome. Especially if you've learned everything you know on the old valve generators and scopes, there's just a huge amount of possibilities.

![Keysight N5182A](/assets/img/vector_signal_generator/n5182.jpg)

For example here are the features I personally find the most important and superior to the conventional generators:

1. Excellent stability;
2. Remote control. It may be setup-and-go case or some scenario;
3. As an extension to the previous point: such devices may be used to create an automated test platform. To explain this idea I have to specify the development cycle of the new equipment.

Let's assume that we have a great and bug-free (which isn't always true) hardware platform, some SoC or an ASIC, and we want to implement a brand-new algorithm. At first developer should do some theoretical investigation to make a plausible model. Models are easy to debug and are very important to estimate the performance and the qualitative characteristics. Then the model has to be modified step by step to approximate or even simulate the hardware platform.

When this stage is over it's time to migrate the algorithm to the external hardware. And to test our brand-new algorithm we create the suiting environment: i.e. series of tests every one on which requires different signal from the generator. Remote control allows us to set up the test script, launch it to acquire the information and have some time to play ping-pong, go for a coffee break, or write an article about how cool is it to be an engineer nowadays.

Today I've found the only flaw in the generator I'm working with: one can't simply run the signal once without an external trigger. The signal state may be set to either the free run (infinite number of repeats), or to the single run by a TTL-trigger. The question is how can I get this trigger (preferably within the Visual Studio)? Two hours of searches and testing stuff from our big box of junk with WinAPI and a multimeter gave me a solution: USB-TTL stick! It's cheap, it interacts with OS like a virtual COM port and it gives great trigger pulses for the generator. 

![USB TTL](/assets/img/vector_signal_generator/usb_ttl.jpg)

Of course any additional hardware is a bad decision. There are some other approaches I've tried, but they're either not working so well or too hard to implement. 

Pretty obvious solution is to start a generator, wait for the signal to end (because the samples quantity and the sampling frequency are known) and turn the generator (Arbitrary waveform generator if precisely) off.  It may be done with something like this:

```cpp
std::this_thred::sleep_for(std::chrono::microseconds(N))  
```

```std::chrono``` is a great tool, it's really precise, but the problems begin when we're dealing with the fast signals (up to 1 ms), because TCP/IP is extremely slow for this signal and won't stop the generator when it's required. The solution is to fill the space afterwards the signal with a lot (A LOT) of zeros, but it's extremely memory inefficient. But, to be honest, I'd pick that option if I hadn't came up with a USB-TTL stick idea.

The other way is to generate two equal signal sections (true signal and zeros), then upload them both to the generation and set up a sophisticated scenario to switch sections on the external trigger. Then make a marker (outgoing trigger) in the end of the signal section and wire the trigger output to the trigger input. Ta-da, magic happens. When the signal is over it'll trigger the zeros section to run and repeat (up to 65k times according to the specifications). Pretty cool, eh? But too much work to do. If the TTL stick will prove itself inefficient that'll be the way I'll try.

UPD: oops, this is what happens when you write an article too soon. I've found a way to control the single burst signals via SCPI. The reputation of the vector signal generators is restored.
