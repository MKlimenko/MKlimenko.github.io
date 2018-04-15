---
# Posts need to have the `post` layout
layout: post

# The title of your post
title: Digital Signal Visualization

# (Optional) Write a short (~150 characters) description of each blog post.
# This description is used to preview the page on search engines, social media, etc.
#description: >
#  Beidou data bit synchronization with Neuman-Hoffman overlay code

# (Optional) Link to an image that represents your blog post.
# The aspect ratio should be ~16:9.
image: /assets/img/digital_signal_visualization/sine.png

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

We live in the digital era. Even if you have no idea what is the difference between RAM and the CPU, or between GSM and GPS, you have to accept the fact that the vast majority of the surrounding things have something digital inside. It may be either a simple RFID chip on a pack of milk or public transport ticket, or a complicated device hidden in a beautiful enclosure.

Everything is great from a consumers point of view, because the devices are getting smarter, smaller and cheaper. Simultaneously with the technology advancement new ideas appear, simplifying our daily routine. We, the engineers, convert those ideas into real devices.

When there are real devices there are real signals, which need to be viewed, analyzed, compared etc. There are several libraries made for this purpose (gnuplot, for example), but they're too complicated for me and overloaded with possibilities. At my work we have an internal library for building one-dimensional signals and it's one hell of a software. It's doing just what you want from it and a bit more. It's great at serving one exact purpose: plotting the signal.

Once I've had an interview and I was asked about any experience in analyzing the signal in the binary form and I was genuinely confused by this question: why would I want to analyse it this way, when it's much easier to plot it and view?

And that's why I've decided to make an application based on our internal library. It does one thing: displays the file you've specified with the parameters you've mentioned. For example, here's the result of passing two files with different data structures (complex vs real, 16-bit vs 8-bit) to the program:

![Digital signal](/assets/img/digital_signal_visualization/sine.png)

Casting to the required type of data is pretty simple, program reads file as an array of bytes (uint8_t actually), and then the pointer to this array passed to the library via the reinterpret_cast. 

One problem isn't solved yet: dealing with packed signals. GNSS signals require only 1 or 2 bits to be efficiently quantized, so why would one want to spend one byte per every sample? Several times I've seen signals, which are packed beyond any reasonable point. It was a signal from GPS/GLONASS L1+L2 receiver and every single byte looked like this (separated to bits):

| | | | | | | | |
|:--|:--|:--|:--|:--|:--|:--|:--|
|GPS L1 Inphase|GPS L1 Quadrature|GLN L1 Inphase|GLN L1 Quadrature|GPS L2 Inphase|GPS L2 Quadrature|GLN L2 Inphase|GLN L2 Quadrature|

For now I can't figure out a way for user to tell the type of packaging to the application. There are some ways, but they're pretty complicated and I don't want to use them. So for now you have to unpack the signal before you visualize it.

Anyway, if you've managed to read this far, you're either interested in this application or one of my friends I've bothered beyond any reasonable level. I'm not pretty sure if I'm allowed by the corporate ethics to give the direct link, but if you need it for non-commercial use, feel free to contact me via the e-mail, which you may find at the right side of this blog.
