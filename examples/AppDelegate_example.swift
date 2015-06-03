//
//  AppDelegate.swift
//  demo
//
//  Created by Christian Sullivan on 5/28/15.
//  Copyright (c) 2015 Bodhi5, Inc. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  // [START register_for_remote_notifications]
  func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions:
    [NSObject: AnyObject]?) -> Bool {
      
    let bundleURL = NSURL(string: "http://10.0.1.2:8081/index.ios.bundle")
    // initialize the rootView to fetch JS from the dev server
    let rootView = RCTRootView(bundleURL: bundleURL, moduleName: "techtime", launchOptions: launchOptions)
    
    // Initialize a Controller to use view as React View
    let rootViewController = ViewController()
    rootViewController.view = rootView
    
    // Set window to use rootViewController
    self.window = UIWindow(frame: UIScreen.mainScreen().bounds)
    self.window?.rootViewController = rootViewController
    self.window?.makeKeyAndVisible()
    
    return true
  }

  func applicationWillResignActive(application: UIApplication) {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
  }

  // [START disconnect_gcm_service]
  func applicationDidEnterBackground(application: UIApplication) {
    
  }

  func applicationWillEnterForeground(application: UIApplication) {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
  }

  func applicationDidBecomeActive( application: UIApplication) {
    // Connect to the GCM server to receive non-APNS notifications
    
  }

  func applicationWillTerminate(application: UIApplication) {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
  }

  // [START receive_apns_token]
  func application( application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken
    deviceToken: NSData ) {
      GCM.appDidRegisterForRemoteNotificationsWithDeviceToken(deviceToken, error: nil)
  }
  
  // [START receive_apns_token_error]
  func application( application: UIApplication, didFailToRegisterForRemoteNotificationsWithError
    error: NSError ) {
      GCM.appDidRegisterForRemoteNotificationsWithDeviceToken(nil, error: error)
    }
  
  func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
    GCM.appDidReceiveRemoteNotification(userInfo)
  }
  
  func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
    GCM.appDidReceiveRemoteNotification(userInfo, handler: completionHandler)
  }
  
}

