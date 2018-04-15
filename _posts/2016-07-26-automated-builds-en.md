---
# Posts need to have the `post` layout
layout: post

# The title of your post
title: Automated builds for C++ projects via GitLab CI

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

First of all: GitLab is an open-source git service. About a year ago, when I asked for any type of source control admins gave me an access to our git server. For a long time I've used only a few of its features, just straightforward git pushes to save my work. However, things were about to change very soon. Currently I'm working on a very complicated project, which involves multiple types of projects (DSP, ARM, API, UI), which requires a lot of SDK’s and IDE’s to build. And when we were forced to wait for three hours to install Qt (hello to corporate proxies), I’ve decided that it would be great to make a dedicated build server, which will pull every new commit from git and handle all the builds. Brief search told me about Jenkins, but I was too lazy to set this thing up. Later that day I’ve visited our corporate git webpage and one menu entry has caught my attention: "Builds". Simply put it’s an integrated build tasker, which engages when new commit is pushed.

To engage the CI you only have to put a file into the root of the repository. There are many possibilities, like perform B only if A fails/succeeds, etc. I’m not so good at it and just update all of the submodules prior to the builds (to acquire the latter libraries), and then perform the builds. If the build job fails, the last pusher is notified that he broke the build. When I was testing this feature, I was receiving something around 50 emails an hour.

There are many examples of .gitlab-ci.yml files for popular languages, but I was unable to find an example of Visual Studio and Qt projects builds. Maybe this will help you:
MSBuild:

```
 Job_name:  
  script:  
  - 'setlocal'  
  - 'chcp 65001'  
  - 'call "%VS120COMNTOOLS%..\..\vc\vcvarsall.bat" x86_amd64'  
  - 'msbuild.exe make\vs120\Project_name.sln /t:Rebuild /p:Configuration=Release /p:Platform="x64" /m'  
  - 'if not exist "%BUILDS%\Project_name" (mkdir "%BUILDS%\Project_name")'  
  - 'copy make\vs120\x64\Release\Project_name.exe "%BUILDS%\Project_name"'  
```

- "Job_name:" string is required and this is how your build/test job will be displayed on the server website.
- "- 'chcp 65001'" is required to display correctly the Cyrillic symbols from MSBuild output.
- "- 'call "%VS120COMNTOOLS%..\..\vc\vcvarsall.bat" x86_amd64'" adds required environment variables, to help shell executor to find MSBuild, C++ compiler etc.

The last two strings help me to store the latter build in the shared folder on the server. It helps a lot when it comes to sharing some of the software I develop.

Easy, huh? Let’s switch to something more interesting, Qt projects!

```
Another_Job_name:  
  script:  
  - 'setlocal'  
  - 'chcp 65001'  
  - 'call "%VS120COMNTOOLS%..\..\vc\vcvarsall.bat" x86_amd64'  
  - 'cd make\qt5'  
  - 'call "%QT_ROOT_x86_64%\bin\qmake.exe" Qt_project.pro -r -spec win32-msvc2013'  
  - 'call "%QT_CREATOR%\bin\jom.exe" -f Makefile.Release'   
  - 'rd /s/q deploy'  
  - 'mkdir deploy'  
  - 'copy release\Qt_project.exe deploy'  
  - 'set curr_dir=%cd%'  
  - 'cd /d "%QT_ROOT_x86_64%\bin"'  
  - 'windeployqt.exe "%curr_dir%\deploy\Qt_project.exe" -no-translations'  
  - 'cd /d %curr_dir%'  
  - 'if not exist "%BUILDS%\Qt_project" (mkdir "%BUILDS%\Qt_project")'  
  - 'xcopy /s /y deploy "%BUILDS%\Qt_project"'  
```

Ah, now that’s interesting. Several similar commands, then we call qmake to create Makefiles from .pro, and then jom (multithreaded make) builds the Release version.

Qt application requires a lot of libraries to run, so we need them all to be present in the final folder. There’s a tool called windeployqt, which analyzes the executable and puts everything right next to it. Somewhy I wasn’t able to make it work without changing the folder, but who cares. xcopy is used to copy everything inside the internal deploy folder to The deploy folder.

It took me a while to realize how to call qmake, jom and windeployqt, but again, nothing too difficult. So I present to you the ARM project build script:

```
 ARM_project_job:  
  script:  
  - 'setlocal'  
  - 'chcp 65001'  
  - 'set command=""%DS-5_DIR%\sw\eclipse\eclipsec.exe" -nosplash --launcher.suppressErrors -application org.eclipse.cdt.managedbuilder.core.headlessbuild -data "%ARM_WORKSPACE%" -import make\eclipse\arm_project -cleanBuild arm_project"'   
  - 'echo "%command%" | "%DS-5_DIR%\bin\cmdsuite.exe" 2> error.txt'  
  - 'for %%A in (error.txt) do set fileSize=%%~zA'  
  - 'del /f /q error.txt'   
  - 'if not %fileSize%==0 (exit /b 1)'  
  - 'if not exist "%BUILDS%\arm_project" (mkdir "%BUILDS%\arm_project")'  
  - 'copy make\eclipse\arm_project\Release\arm_project.axf "%BUILDS%\arm_project"'  
```

The interesting part here is the piping the %command% to the cmdsuite.exe. Cmdsuite is a DS-5 command prompt, batch job with some internal magic about licensing and configuring databases. I call it magic I failed at trying to export all of the environment variables to the system. The problem is how to pass the command to the batch job? Somehow piping works. The command itself is just a call for the eclipse without logo, ordering it to import the acquired project and build it in headless mode. Attention! If you have a project with the same name imported into your DS-5 workspace on that PC, eclipse won’t be able to import it and, therefore, to build it. Then I redirect the output of the build to the text file and read it later in the main thread (command prompt). This is required, because the batch job output is suppressed and isn’t available for gitlab CI to analyze. If the file is not empty, I presume that there are errors and exit with error code 1, which marks the build as failed. Otherwise, I have the latest build ARM executable in the shared folder.                 
