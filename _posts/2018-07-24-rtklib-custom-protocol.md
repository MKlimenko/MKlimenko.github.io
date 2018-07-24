---
layout: post
title: RTKLib custom GNSS receiver protocol integration
lang: en
categories: [english]
tags: [C++, GNSS]
comments: true
---

Every GNSS engineer has heard of the RTKLib. It's an [open source](https://github.com/tomojitakasu/RTKLIB/) toolkit for real-time and post-processing of the raw GNSS data. The availability of such a toolkit is somewhat of a revolution: it allowed small companies to step into the high-precision navigation market without the need for spending a lot of time and money on R&D tasks. There are, however, some limitations and drawbacks:

1. No developer API or documentation. You have to scrap the information of the Internet, debug and reverse-engineer, which is highly inefficient.
2. Everything is implemented in plain C, which upsets me, as a C++ enthusiast. There are a whole lot of typical C problems: no type checking, `#define`d constants etc

In this article, I'll tell how I've added our research-oriented protocol into the RTKLib. With the protocol implemented, we've added several perks to our receiver:

1. Production-quality RINEX-converter, familiar for the GNSS engineers.
2. Real-time navigation application, capable of RTK and PPP.

There are two major independent parts that we need to do:

1. Let the RTKLib (and tools) know about our receiver. This means:
    * Enhance the interface in the `rtklib.h` header;
    * Extend receiver-dependent functions in the `rcvraw.c` source file;
    * Update the application code in terms of the displayed help file and another.
2. Decode incoming messages and fill the internal structures with the corresponding data

As a C++ enthusiast, I've implemented the protocol support with C++, but you're free to use plain C if you wish.

- [RTKLib interface for the receivers](#rtklib-interface-for-the-receivers)
- [Receiver-dependent functions](#receiver-dependent-functions)
- [Extending the application code](#extending-the-application-code)
- [Filling the internal structures](#filling-the-internal-structures)
- [Conclusion](#conclusion)

## RTKLib interface for the receivers

The main file with all the interfaces is called `rtklib.h`. First of all, let's make it serious and create our format. For this we have to extend the list of `STRFMT_XXX` defines with our own. I've decided to put our receiver next to the Trimble because why not? 

This list of defines should really be the `enum`, but since it isn't we have to deal with numbers ourselves: don't forget to shift all of the `#define`d values and increment the `MAXRCVFMT` value.

For every receiver, two functions should be defined in there: one for the real-time processing, the other for dealing with files:

```cpp
int input_%protocol_name%(raw_t *raw, unsigned char data);

int input_%protocol_name%f(raw_t *raw, FILE *fp);
```

The first function receives a pointer to the `raw_t` object and a byte from the stream. We'll talk about the implementations a bit later. The second function handles the file itself and fills the raw measurement data.

Although functions return an integer, it's a C way to spell `enum`. After some reverse engineering, here are the codes and corresponding values:

```cpp
enum ReturnCodes {
    end_of_file = -2,
    error_message = -1,
    no_message = 0,
    input_observation_data = 1,
    input_ephemeris = 2,
    input_sbas_message = 3,
    input_ion_utc_parameter = 9,
    input_lex_message = 31
};
```

Here I'd like to point out, that one should prefer strictly typed enumerator (`enum class`) in every case possible. In of the times, this isn't possible is working with the existing API, such as RTKLib. 

## Receiver-dependent functions

Every application that has to deal with receivers calls the wrapper functions:

```cpp
extern int input_raw(raw_t *raw, int format, unsigned char data);

extern int input_rawf(raw_t *raw, int format, FILE *fp);
```

Inside of those, there is a switch on the format (discussed above) to call the corresponding function. Just add the line with your receiver and you're good to go.

Another important step is to extend the array of receiver names in the `rtkcmn.c` file: extend the `const char *formatstrs[32]` array. And don't mix the numbers!

## Extending the application code

Here we'll discuss the convbin (RINEX-converter) application, others are pretty much the same. There are several things we need to edit:

1. The description/help information in the `static const char *help[]` array. Tell the users about your receiver, supported messages etc;
2. Choose the format name for the `-r` switch. Add it to the help information and to the format selection list of comparisons (`if (*fmt) //...`).
3. If your logger/visualisation software has a specified extension for the file, add it to the help information and to the extension detector block just below the format selection. It is useful for the protocol auto-detection.

## Filling the internal structures

Now comes the interesting part where we'll implement the [receiver-dependent functions](#receiver-dependent-functions). As I've mentioned earlier, I've made it with C++. I've created a header with the protocol description and some helper functions.

To link C++ code with plain C applications you have to mark functions `extern "C"`, which will take care of the [name mangling](https://en.wikipedia.org/wiki/Name_mangling#C++). Also, make sure to catch all the exceptions if your functions may throw because exception propagation to C code is undefined behaviour.

```cpp
extern "C" int input_%protocol_name%(raw_t *raw, unsigned char data) {
    try {
        // ...
    }
    catch (...) {
        return ReturnCodes::error_message;
    }
}
```

We'll be adding relatively basic support for the protocol. There are three basic fields in the `raw_t` structure, that we're interested in. others are either too specific or service fields. We'll fill the observation, ephemeris data and the time tag:

```cpp
typedef struct {        /* receiver raw data control type */
    gtime_t time;       /* message time */
    obs_t obs;          /* observation data */
    nav_t nav;          /* satellite ephemerides */
    // ...
} raw_t;
```

`gtime_t` is trivial and represents total time of the message with integer (`time_t`) and fractional (`double`) part of the second.

Moving on to the raw observations data. We have the following struct declared in the `rtklib.h` header:

```cpp
typedef struct {        /* observation data */
    int n,nmax;         /* number of obervation data/allocated */
    obsd_t *data;       /* observation data records */
} obs_t;

typedef struct {        /* observation data record */
    gtime_t time;       /* receiver sampling time (GPST) */
    unsigned char sat,rcv; /* satellite/receiver number */
    unsigned char SNR [NFREQ+NEXOBS]; /* signal strength (0.25 dBHz) */
    unsigned char LLI [NFREQ+NEXOBS]; /* loss of lock indicator */
    unsigned char code[NFREQ+NEXOBS]; /* code indicator (CODE_???) */
    double L[NFREQ+NEXOBS]; /* observation data carrier-phase (cycle) */
    double P[NFREQ+NEXOBS]; /* observation data pseudorange (m) */
    float  D[NFREQ+NEXOBS]; /* observation data doppler frequency (Hz) */
} obsd_t;

typedef struct {        /* navigation data type */
    /// ...
    eph_t *eph;         /* GPS/QZS/GAL ephemeris */
    geph_t *geph;       /* GLONASS ephemeris */
    /// ...
} nav_t;
```

`obs` is a wrapper for an array of observation data records for every satellite. `NFREQ` and `NEXOBS` are `#define`d constants, resolved at compile-time. Everything is pretty straightforward here, just make sure to keep all the dimensions right.

## Conclusion

With all of the above said and done, we've implemented our protocol in the RTKLib and all of its tools and ecosystem became available for our developers and clients.