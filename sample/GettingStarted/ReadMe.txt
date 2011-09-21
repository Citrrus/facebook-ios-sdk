### Getting Started (iOS) ###

Demonstrates how to use the Facebook Platform to integrate your iOS app. This sample initially asks the user to log in to Facebook then provides the user with a sample set of Facebook API calls such as logging out, uninstalling the app, publishing news feeds, making app requests, etc.

Build Requirements
iOS 4.0 SDK


Runtime Requirements
iPhone OS 4.0 or later


Using the Sample
Install the Facebook iOS SDK. Save this sample file in the <iOS SDK>/sample directory. Launch the Accessory project using Xcode.

To run in the simulator, set the Active SDK to Simulator. To run on a device, set the Active SDK to the appropriate Device setting. When launched, touch the entire row to make the accessory view appear checked, touch again to uncheck it. Then touch the actual accessory to the right to check and uncheck it as well.


Packaging List
GettingStartedAppDelegate.{h/m} -
The app delegate class used for managing the application's window and navigation controller.

RootViewController.{h/m} -
The root view controller used to set up the main menu and initial API calls to set the user context (basic information and permissions).

APICallsViewController.{h/m} -
View controllers pushed from the root view controller. Used to handle each of the API sub-sections. Most of the Facebook API examples are contained here.

APIResultsViewController.{h/m} -
View controllers pushed from the API calls view controller. Handles mostly displaying API call results that are not simple confirmations. Also handles any post-result API calls, such as checking in from a list of nearby places.

DataSet.{h/m} -
Class that defines the UI data for the app. The main menu, sub menus, and methods each menu calls are defined here. 

Changes from Previous Versions
1.0 - First release.

Copyright (C) 2010 Facebook
