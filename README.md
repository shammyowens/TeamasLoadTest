# TeamasLoadTest
> This project is a set of PowerShell scripts which can be used to load test Citrix SBC or VDI environment and/or test application performance

## Table of contents
* [General info](#general-info)
* [Screenshots](#screenshots)
* [Scripts](#Scripts)
* [Setup](#setup)
* [Features](#features)
* [Status](#status)
* [Inspiration](#inspiration)
* [Contact](#contact)

## General info
This project was born out of need to do Non Functional Performance testing.  Our licence for LoginVSI had lapsed.  To work around this issue, I created the load testing tools using PowerShell.  Since that project, I have developed it a bit further and I felt like others could leverage this if they needed to.

I completed a presentation at the Winter 2019 UK Citrix User Group.  A copy of this presentation can be found [here](/images/pres.pptx)

## Screenshots
![Control - Version 4.0 - Multi Launcher](/images/controlv4.png)

[![Workload Script Demo](https://img.youtube.com/vi/c3H_ohaawik/hqdefault.jpg)](https://youtu.be/c3H_ohaawik)
[![Controlv4 Multi Launcher Demo](https://img.youtube.com/vi/uTf_ibhPEZA/hqdefault.jpg)](https://youtu.be/uTf_ibhPEZA)

To view previous versions, see my channel on YouTube
https://www.youtube.com/playlist?list=PL2EN6uDanDrwVOXdehBUCBoWTw2jbyxhZ

## Scripts
* Control - version 1.0 - This is a simple PowerShell script to launch sessions
* Control - version 2.0 - Single Launcher - This is a GUI PowerShell script to launch sessions
* Control - version 3.0 - Multi Launcher -  This is a GUI PowerShell script to connect to separate launcher machines.
* Control - version 4.0 - Multi Launcher -  This is a GUI PowerShell script to connect to separate launcher machines, functions are in ControlFunctions.psm1 file and provides feedback on Launcher status.

* Colourpicker - version 1.0 - This is a GUI PowerShell script to get RGB colours from cursor position
* Colourloop - version 1.0 - This is a PowerShell script return RGB values for a pixel and loop.  Useful for building workload scripts when page is refreshes.

## Setup
* Create a file share and copy the contents of this project in at the root.  Ensure the test users can write to the status and errors folders (this is for the endtest.txt signaller file and to copy error screenshots)

* Copy the workload.ps1 script and amend the Initialize-Test and Start-Test functions to complete whatever workloads you want to run.

* On each VDA, ensure that there is a c:\temp directory that each test user can write to.

* Ensure that the launched app/desktop is set to Auto to be published in test user favourites and that storefront does not auto launch apps.

* Ensure that StoreFront URL is in trusted sites on Launcher VMs.  Otherwise the script will pause asking for the ICA file to be downloaded.

* Ensure that scripts\start.bat file is set to unblocked (file > properties > Unblock) otherwise Login Script will prompt use to run script.


### Single Launcher
Run Control-SingleLauncher.PS1 from your launcher VM (must have Citrix Workspace or Receiver client).  This loads the GUI from the gui.xaml file.  This file also includes the default options for each element and they can be amended to suit.

Apart from
* Domain is automatically picked up from machine
* Fileshare is picked up from the launched location

### Multi Launcher
For Multi Launcher, login to launcher VMs (need Citrix Receiver/Workspace installed) and run the scripts\startlauncher.ps1 file.  This will ask for the password for the test user accounts.  It will then loop until test started.  From a controller machine, run control-multilauncher.ps1 and enter the relevant information.  Click Start Test.

This will create some files in the status folder.  The launchers will check this folder and begin the test.

## Features
* Performance monitor logs will be placed in the perfmon folder after a test
* Step timing will be placed in the timings folder after a test
* Any errors (x3) will take a screenshot and placed in the errors folder.
* Central way of controlling launchers

To-do list:

* Auto creation of c:\temp drive on each VDA with permissions
* Tidying up code
* Error Handling/Logging
* Workload Recorder

## Status
Project is: _in progress_ but as I do not manage Citrix these days, my input will be limited.

## Inspiration
Below are some of the links I used to help with this project.  There are some other functions and code I have used from the Internet.  Where possible, I have commented with the originating link in the script or in the PPTX.

Powershell Runspaces
https://foxdeploy.com/2016/05/17/part-v-powershell-guis-responsive-apps-with-progress-bars/
https://learn-powershell.net/2012/10/14/powershell-and-wpf-writing-data-to-a-ui-from-a-different-runspace/

Template for WPF with runspaces
https://github.com/1RedOne/BlogPosts/blob/master/GUI%20Part%20V/PowerShell_GUI_Template.ps1

Debug Runspaces
https://devblogs.microsoft.com/powershell/powershell-runspace-debugging-part-1/

Jim Moyle WPF (EP7 and 8) and Powershell (runspaces)
https://www.youtube.com/watch?v=0WZVqe9DEK8

Script for launching Citrix Sessions
https://github.com/santiagocardenas/storefront-launcher/blob/master/SFLauncher.ps1

Getting session information in PowerShell
https://github.com/jeremysprite/ps-quser/blob/master/Get-LoggedOnUsers.ps1

GitHub Readme cheat sheet
https://github.com/ritaly/README-cheatsheet

## Contact
Created by [@shammyowens](https://www.twitter.com/shammyowens)

[Teamas Blog](https://www.teamas.co.uk)

[If this has been useful, feel free to buy me a coffee :-)](https://ko-fi.com/shammyowens)
