---
# Posts need to have the `post` layout
layout: post

# The title of your post
title: Prefer static class members

# (Optional) Write a short (~150 characters) description of each blog post.
# This description is used to preview the page on search engines, social media, etc.
#description: >
#  Beidou data bit synchronization with Neuman-Hoffman overlay code

# (Optional) Link to an image that represents your blog post.
# The aspect ratio should be ~16:9.
#image: /assets/img/digital_signal_visualization/sine.png

# You can hide the description and/or image from the output
# (only visible to search engines) by setting:
# hide_description: true
# hide_image: true
lang: en

# (Optional) Each post can have zero or more categories, and zero or more tags.
# The difference is that categories will be part of the URL, while tags will not.
# E.g. the URL of this post is <site.baseurl>/hydejack/2017/11/23/example-content/
categories: [english]
tags: [C++]
# If you want a category or tag to have its own page,
# check out `_featured_categories` and `_featured_tags` respectively.
---

Long time no see. Let us talk about one minor thing just to keep going.
In real-time applications often, it is the matter of microseconds. In practice, a hot path should be optimized as well as possible, often rewritten in assembly. For example, we have a class that encapsulates some data and has some methods. In addition, one of the methods works perfectly fine without accessing the internal data: 

```cpp
struct Foo {
    // .. some members
    void SophisticatedCopy(const unsigned* src, unsigned* dst) {
        // .. sophisticated algorithm
    }
} foo;

void bar(){
    foo.SophisticatedCopy(src, dst);
}
```

When you call a class method it silently passes ```this``` pointer to the function. It is clear from the assembly (thanks to Matt Godbolt):

```assembly
foo DB 01H DUP (?)
bar PROC
sub rsp, 40 ; 00000028H
mov r8, QWORD PTR dst
mov rdx, QWORD PTR src
lea rcx, OFFSET FLAT:foo   // <-------
call Foo::SophisticatedCopy
add rsp, 40 ; 00000028H
ret 0
bar ENDP
Foo::SophisticatedCopy, COMDAT PROC
mov QWORD PTR [rsp+24], r8
mov QWORD PTR [rsp+16], rdx
mov QWORD PTR [rsp+8], rcx // <-------
ret 0
Foo::SophisticatedCopy ENDP
```

Static members have no access to internal data, because they are independent from the object. Can we use it as an advantage? 

```cpp
struct Foo {
    // .. some members
    static void SophisticatedCopyStatic(const unsigned* src, unsigned* dst) {
        // .. sophisticated algorithm
    }
} foo;

void bar_static(){
    foo.SophisticatedCopyStatic(src, dst);
}
```

Turns out we can!

```assembly
bar_static PROC
sub rsp, 40 ; 00000028H
mov rdx, QWORD PTR dst
mov rcx, QWORD PTR src
call Foo::SophisticatedCopyStatic
add rsp, 40 ; 00000028H
ret 0
bar_static ENDP
Foo::SophisticatedCopyStatic, COMDAT PROC
mov QWORD PTR [rsp+16], rdx
mov QWORD PTR [rsp+8], rcx
ret 0
Foo::SophisticatedCopyStatic ENDP
```

You may say "Why would I want to save two processor instructions? They’re cheap!" and most of the time you would be correct. However, imagine a system (real-time, mostly), that calls this function ten thousand times a second. That is twenty thousand extra instructions that have no point. Small optimization, but pays off well.