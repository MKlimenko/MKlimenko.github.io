---
layout: post
title: FIR-based electric guitar cabinet simulation explained
lang: en
categories: [english]
tags: [C++]
comments: true
---

It is extremely useful to have a little vacation every once in a while, to distract yourself from your day-to-day basis. You may find yourself thinking about various tasks you were too busy to give some serious time to. One of such tasks I was intrigued about is the guitar cabinet simulation via the impulse responses of the real cabinet-microphone pair.

## Introduction

Let's analyze the traditional electric guitar signal chain. We have a nice looking strat, some guitar cable, effects (missing here, as well as the effects loop), amplifier and the cabinet. Every part of this chain is important. The guitar (with your help, of course) produces the music, which is then transferred by the guitar cable to the amplifier. 

Electric guitar amplifiers are different species than the HiFi ones. This is because the main purpose of the amplifier is not to make the signal louder, but to distort it in a way, that's pleasant to the human ear. HiFi ones, on the contrary, are designed to be as transparent as possible. At the end of the signal chain, there is a cabinet, which is, mainly, a speaker in a box. This is what we'll discuss further in this article.

> One part of the signal chain that is being overlooked more often, than it should be, is the guitar cable. An important characteristic of the cable is its capacitance. If the cable is long enough, it acts as a low-pass filter (RC-circuit) and cuts some of the high frequencies. A friend of mine once told me, that he almost sold his guitar due to the "muddy" sound. What a relief it was for him when he swapped the cable for a good one. Bear in mind, that for active pickups the influence of the cable is almost neglectable. 

![Traditional signal chain](/assets/img/fir-guitar-cabinet/schematic.png)

## Guitar cabinets

First of all, let's grey out the parts of the scheme, that we're not currently interested in, and only leave the cabinet highlighted. The cabinet is used for the:

1. Conversion of the electric signal to the sound waves (sound);
2. Low-pass filtering of the signal.

![Part of interest](/assets/img/fir-guitar-cabinet/cabinet_greyed.png)

Amplified (and distorted) guitar signal has a lot of harmonics, especially in the high frequencies, which is harsh and doesn't sound good. To solve this, most guitar speakers have a steep cutoff at around 6-8 kHz. Here's an example of the frequency response of the cabinet (some Mesa Boogie if I recall correctly).

![Frequency response](/assets/img/fir-guitar-cabinet/frequency_response_db.png)

The task is to emulate this behaviour with digital signal processing techniques.

## Guitar cabinet simulation

A guitar cabinet is a linear device and may be modelled as a digital FIR filter. **FIR** stands for finite impulse response and it's the kind of digital filter where you don't have any internal feedback.

![Fir schematic](https://upload.wikimedia.org/wikipedia/commons/thumb/9/9b/FIR_Filter.svg/1200px-FIR_Filter.svg.png)


The math behind FIR-filters is quite simple: for each output sample you multiply the last N input samples with the corresponding coefficients (often called weights) and accumulate them:

$$y[n] = b_0x[n] + b_1x[n-1] + ... + b_Nx[n-N] = \sum_{i=0}^Nb_ix[n-i]$$

This process is also known as convolution, becoming more famous with the rising popularity of the artificial convolutional neural networks.

## Influence of the guitar cabinet

Let's assume we have a nice little guitar part which has been directly recorded with a sound card or some DI-box: 

<iframe width="100%" height="300" scrolling="no" frameborder="no" allow="autoplay" src="https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/tracks/1265562760&color=%23ff5500&auto_play=false&hide_related=false&show_comments=true&show_user=true&show_reposts=false&show_teaser=true&visual=true"></iframe><div style="font-size: 10px; color: #cccccc;line-break: anywhere;word-break: normal;overflow: hidden;white-space: nowrap;text-overflow: ellipsis; font-family: Interstate,Lucida Grande,Lucida Sans Unicode,Lucida Sans,Garuda,Verdana,Tahoma,sans-serif;font-weight: 100;"><a href="https://soundcloud.com/michael-klimenko-331527785" title="Michael Klimenko" target="_blank" style="color: #cccccc; text-decoration: none;">Michael Klimenko</a> · <a href="https://soundcloud.com/michael-klimenko-331527785/dry-1" title="Dry" target="_blank" style="color: #cccccc; text-decoration: none;">Dry</a></div>

It sounds a bit dull, but that's a start. According to our diagram above here, we have a guitar and a cable. The next step would be the amplifier (with some optional effects). For the sake of demonstration let's assume that we want a gainy amplifier. High-gain amplifiers are used to get some nonlinear distortion to the input signal, which results in an enrichment of the original signal with harmonics. Be careful, the following sound isn't what you'd call pleasant.

<iframe width="100%" height="300" scrolling="no" frameborder="no" allow="autoplay" src="https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/tracks/1265562754&color=%23ff5500&auto_play=false&hide_related=false&show_comments=true&show_user=true&show_reposts=false&show_teaser=true&visual=true"></iframe><div style="font-size: 10px; color: #cccccc;line-break: anywhere;word-break: normal;overflow: hidden;white-space: nowrap;text-overflow: ellipsis; font-family: Interstate,Lucida Grande,Lucida Sans Unicode,Lucida Sans,Garuda,Verdana,Tahoma,sans-serif;font-weight: 100;"><a href="https://soundcloud.com/michael-klimenko-331527785" title="Michael Klimenko" target="_blank" style="color: #cccccc; text-decoration: none;">Michael Klimenko</a> · <a href="https://soundcloud.com/michael-klimenko-331527785/without-cabinet-1" title="Without cabinet" target="_blank" style="color: #cccccc; text-decoration: none;">Without cabinet</a></div>

It has a lot of so-called "sand" and this isn't something you want to hear on your recording or while jamming on your couch. To mitigate that the cabinet is used to get something like this:

<iframe width="100%" height="300" scrolling="no" frameborder="no" allow="autoplay" src="https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/tracks/1265562757&color=%23ff5500&auto_play=false&hide_related=false&show_comments=true&show_user=true&show_reposts=false&show_teaser=true&visual=true"></iframe><div style="font-size: 10px; color: #cccccc;line-break: anywhere;word-break: normal;overflow: hidden;white-space: nowrap;text-overflow: ellipsis; font-family: Interstate,Lucida Grande,Lucida Sans Unicode,Lucida Sans,Garuda,Verdana,Tahoma,sans-serif;font-weight: 100;"><a href="https://soundcloud.com/michael-klimenko-331527785" title="Michael Klimenko" target="_blank" style="color: #cccccc; text-decoration: none;">Michael Klimenko</a> · <a href="https://soundcloud.com/michael-klimenko-331527785/full-1" title="Full" target="_blank" style="color: #cccccc; text-decoration: none;">Full</a></div>

The simplicity of this approach has resulted in a big number of products related to the cabinet simulation, which is great for musicians who gig a lot to get a reproducible tone as well as the recording guitarists to reamp and get the sound they're looking for.