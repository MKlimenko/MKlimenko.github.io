---
# Posts need to have the `post` layout
layout: post

# The title of your post
title: Предпочитайте статические методы классов

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
lang: ru

# (Optional) Each post can have zero or more categories, and zero or more tags.
# The difference is that categories will be part of the URL, while tags will not.
# E.g. the URL of this post is <site.baseurl>/hydejack/2017/11/23/example-content/
categories: [russian]
tags: [C++]
# If you want a category or tag to have its own page,
# check out `_featured_categories` and `_featured_tags` respectively.
---

Давно не виделись, как-то забегался и не мог найти время написать. Давайте начнем разговор о небольшой вещи, а потом пойдут более серьезные статьи. Тем более, переезд на GitHub Pages это отличный повод попробовать что-то новое. 
В приложениях реального времени счет зачастую идет на микросекунды. На практике это означает, что горячий путь программы должен быть максимально оптимизирован, вплоть до написания на ассемблере. Допустим, у нас есть класс, который содержит некоторые поля с данными и методы. Вдобавок, один из методов прекрасно работает без доступа к внутренним данным объекта:

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

При вызове метода класса происходит неявная передача указателя ```this``` в функцию. Это прекрасно видно в генерируемом ассемблере (спасибо, Matt Godbolt!):

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

Статические методы не имеют доступа к внутренним данным, поскольку они не привязаны ни к какому объекту. Можем ли мы использовать это в качестве преимущества?

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

Оказывается, что можем!

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

Вы можете сказать: "Зачем мне пытаться сэкономить две процессорные инструкции? Они же дешёвые," — и в большинстве случаев будете правы. Однако, представьте систему (чаще всего, реального времени), которая вызывает эту функцию десять тысяч раз в секунду. Это двадцать тысяч лишних инструкций, в которых нет абсолютно никакого смысла. Это маленькая оптимизация, которая дает очень хороший выигрыш. 
