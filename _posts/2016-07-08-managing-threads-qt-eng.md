---
# Posts need to have the `post` layout
layout: post

# The title of your post
title: Managing threads in Qt

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

# (Optional) Each post can have zero or more categories, and zero or more tags.
# The difference is that categories will be part of the URL, while tags will not.
# E.g. the URL of this post is <site.baseurl>/hydejack/2017/11/23/example-content/
categories: [english]
tags: [C++]
# If you want a category or tag to have its own page,
# check out `_featured_categories` and `_featured_tags` respectively.
---

I was writing a little post about performing a remote power reset, but it is not quite there yet, so I’ll share with you some of the ideas about multithreading in UI applications. Let’s say we’re developing a simple client-server application that is required to use a callback function every time there is new data available. Therefore, we need to listen the port for the incoming data constantly, which is impossible in the main thread. Here comes the multithreading: we have to spawn a listener thread, while our main thread is waiting for the instructions.

There are two ways to create a parallel application in C++: thread-based and task-based. ```std::thread``` vs ```std::async```. I personally prefer the ```std::thread``` way, simply because std::async need the ```std::launch::async``` policy specified for the true asynchronous calculations.

For example, let’s use a class:

```cpp
class Foo {
private:
    std::thread RxThread;
    //…
    void InfiniteRead(std::function<void(uint8_t*, size_t &)> callback) {
          for (;;) {
                 //Read Some Data
                 if(read) {
                        callback(data, size_of_data);
                 }
          }
    }
    //…
public:
    void Init() {
        RxThread = std::thread(&Foo::InfiniteRead, this, callback);
    }
};
```

Voila! We’ve spawned a thread, which constantly reads data and calls some function on received data. Problems start when we need to update the UI according to the received data. It is a bad habit to change anything in the UI from other threads, because you never know if it’s being updated from the main thread right now.

One should use events in Qt to update the UI from (sort of) another thread. Firstly you should declare a class, which would handle the events:

```cpp
class MyEvent : public QEvent{
public:
        struct event_msg{
            //some custom struct with data
        };   

    MyEvent(const event_msg& message) : QEvent(QEvent::User) {_message = message;}
    ~MyEvent() {}

    event_msg message() const {
        return _message;
    }

private:
    event_msg _message;
};
```

Then you declare a simple method in the UI header file:

```cpp
bool event(QEvent* event);
```

With the following implementation:

```cpp
bool UI_Class::event(QEvent* event){
    if (event->type() == QEvent::User){
        MyEvent* postedEvent = static_cast<MyEvent*>(event);
        //some code
    }
    return QWidget::event(event);
}
```

In the overridden event method, we check the event type, and if it is the one we’ve made, we execute some commands. Otherwise, we send the event further down the food chain. And the last thing is how to send such events:

```cpp
void blabla(){
    ...
    MyEvent::event_msg event;
    //fill event_msg with data
    MyEvent* e = new MyEvent(event);
    QCoreApplication::postEvent(parent, e);
}
```

Done. As simple as that. Also, it’s very good idea to notify the thread via the ```std::condition_variable```, that you’ve received some data. 
