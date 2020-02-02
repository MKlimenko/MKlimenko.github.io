---
layout: post
title: GitLab CI for C++ projects
lang: en
categories: [english]
tags: [C++]
comments: true
---

In 2016, before moving to GitHub pages as a hosting platform for this blog, I wrote a little [post](https://mklimenko.github.io/english/2016/07/26/automated-builds-en/) about CI and automated builds for C++ projects as a synopsis for the week I spent at work with this task. Currently, we're modernizing the technological stack for one of our paramount product (neural network middleware for the NeuroMatrix processors called **NMDL**) and one of the tasks is to configure and maintain the continuous integration system. The modernizing process also involved integration and renovation of tools, projects, architecture VCS and various "best practices", I hope I'll compile it as a talk at some C++ conference.

> TL;DR: GitLab CI is a great instrument to build, test and deploy C++ projects and it takes less than an hour to setup. There's a [repo](https://gitlab.com/mklimenko29/ci_example) with some minimal build and test code you may start with.

## Project structure

Throughout this whole post I'll be referring to this [repo](https://gitlab.com/mklimenko29/ci_example), which is a simplified representation of the project structure we use in our projects:

- `src` folder, which contains source files of the project. We tend to keep the header files and various `.ui` stuff here as well. For our purposes it contains:
  - `lib.hpp` — a header-only library we intend to use and test. It contains a simple `Add` function template which, according to its' name, summarizes two numbers and returns the result
  - `main.cpp` with simple usage of the library
- `test` folder is introduced to separate the project code from the tests. In this folder we have:
  - `test.cpp` — the test itself, written to use the [googletest](https://github.com/google/googletest) library. I prefer it to others (such as Catch2, or the Boost.Test, but it's up to you to choose which one you like)
  - `CMakeLists.txt` — simple CMake script, which is responsible for building the tests
  - `CMakeLists.txt.in` — a little CMake helper, designed to download the latest `googletest` library version and build it. It provides tight integration with the build process of the tests themselves and leads to more isolated (in a good way) builds. 
- Global `CMakeLists.txt` designed to build and test the library
- Default `.gitignore` as a sign of good manners
- `.gitlab-ci.yml` — the most important file for this post, this is the script that defines the structure and order of pipelines. 

When the project is ready, it is time to set up the CI.

## Step 1: set up the runner

To familiarize you with CI, I'll provide a brief simplified explanation of what we're about to achieve. Our ultimate goal is to constantly check whether the current version of our product (library, project etc) is good enough to be shipped. This can be verified by running the set of predefined tests for every pushed commit of the repository. The program used for it is called the runner. Every time there's a new commit, GitLab (both the original one and the self-hosted, whichever you prefer) will notify the runner, so it could fetch the latest changes and perform the actions you've listed int the `.gitlab-ci.yml` file.

Installing the runner for Windows is extremely easy, just follow the [instructions](https://docs.gitlab.com/runner/install/) from GitLab. During the installation, the runner will ask you to provide some information and will register itself as a service.

I've had a couple of difficulties with the runner, which I'll list to save you some time:

1. Make sure you have `git.exe` added to your `PATH` environment variable;
2. The runner registers itself as a system service, which may not be something you want. If you're getting some weird access errors, find the `gitlab-runner` in the services (Start -> `services`) and change the login type to one of the administrator accounts you have on that server.
3. I'd like to state this as a separate point if you want to use WSL (Windows Subsystem for Linux, lightweight virtual machine in Windows 10, highly recommend!) be aware, that the WSL currently is installed per-user, therefore, to make it available for the runner, the runners' service must be logged-in via that account.

## Step 2: come up with the CI scenario

After the runner is set, you're almost good to go. You have a server to run your tasks, optionally, some specific hardware and a repository. It's obvious, but be sure to install all the required developer environment at the server you'll build your project on.

This is the where CMake shines. If you've done everything correctly, all you have to do is just these simple commands:

```
mkdir build && cd build
cmake ..
cmake --build .
ctest .
```

The thing I love the most about that approach is that it's entirely cross-platform. CMake will generate Visual Studio solutions for Windows and Makefiles for Linux. You don't have to write specific build scripts, just one common `CMakeLists` will do. 

Of course, it is always better to separate the CI script into several stages, so if something fails, you won't have to read all the listing to reveal the part where everything went wrong. 

There are numerous additional topics one may cover. Here I've provided the very basics for you to start integrating CI into your project and making it a little better every time.