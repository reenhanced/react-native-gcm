//
//  GCM.swift
//  techtime
//
//  Created by Christian Sullivan on 5/28/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

import Foundation

let GCM_MESSAGE_RECEIVED_EVENT = "GCMMessageReceived"
let GCM_REGISTERED_CLIENT_EVENT = "GCMRegisteredClient"
let GCM_RECEIVED_DEVICE_TOKEN_EVENT = "GCMReceivedDeviceToken"

@objc(GCM)
class GCM: NSObject, GGLInstanceIDDelegate {
  

  static let DESTRUCT_EVENT = "destruct"
  static let CONNECTION_EVENT = "connection"
  static let DISCONNECT_EVENT = "disconnect"
  static let REGISTERED_CLIENT_EVENT = "registeredClient"
  static let ENTERED_BACKGROUND_EVENT = "enteredBackground"
  static let BECAME_ACTIVE_EVENT = "becameActive"
  static let MESSAGE_EVENT = "message"
  
  //MARK: Class Methods
  
  class func appDidReceiveRemoteNotification(userInfo: [NSObject: AnyObject]){
    // This works only if the app started the GCM service
    GCMService.sharedInstance().appDidReceiveMessage(userInfo);
    NSNotificationCenter.defaultCenter().postNotificationName(GCM_MESSAGE_RECEIVED_EVENT, object: nil, userInfo: userInfo)
  }
  
  class func appDidReceiveRemoteNotification(userInfo: [NSObject: AnyObject], handler: (UIBackgroundFetchResult) -> Void) {
    // This works only if the app started the GCM service
    GCM.appDidReceiveRemoteNotification(userInfo)
    handler(UIBackgroundFetchResult.NoData)
  }
  
  class func registrationHandler(registrationToken: String!, error: NSError!) {
    let userInfo: [String:AnyObject]
    if registrationToken != nil {
      userInfo = ["registrationToken": registrationToken]
    } else {
      userInfo = ["error": error]
    }
    NSNotificationCenter.defaultCenter().postNotificationName( GCM_REGISTERED_CLIENT_EVENT, object: nil, userInfo: userInfo)
  }
  
  class func appDidRegisterForRemoteNotificationsWithDeviceToken(deviceToken: NSData!, error: NSError! ) {
    let userInfo: [String: AnyObject]
    if deviceToken != nil {
      userInfo = ["deviceToken": deviceToken]
    } else {
      userInfo = ["error": error]
    }
    NSNotificationCenter.defaultCenter().postNotificationName( GCM_RECEIVED_DEVICE_TOKEN_EVENT, object: nil, userInfo: userInfo)
  }
  
  var bridge: RCTBridge!
  var connectedToGCM = false
  var subscribedToTopic = false
  var gcmSenderID: String?
  var deviceToken: NSData?
  var registrationToken: String?
  var registrationOptions = [String: AnyObject]()
  
  //MARK: Instance Methods
  
  @objc override init() {
    super.init()
    let nc: NSNotificationCenter = NSNotificationCenter.defaultCenter();
    nc.addObserver(self, selector: "_applicationDidEnterBackground:", name: UIApplicationDidEnterBackgroundNotification, object: nil)
    nc.addObserver(self, selector: "_applicationDidBecomeActive:", name: UIApplicationDidBecomeActiveNotification, object: nil)
    
    nc.addObserver(self, selector: "_appRegisteredWithToken:", name: GCM_RECEIVED_DEVICE_TOKEN_EVENT, object: nil)
    nc.addObserver(self, selector: "_handleRegistration:",    name: GCM_REGISTERED_CLIENT_EVENT, object: nil)
    nc.addObserver(self, selector: "_handleMessageReceived:", name: GCM_MESSAGE_RECEIVED_EVENT, object: nil)
  }
  
  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self)
    self.emitEvent(GCM.DESTRUCT_EVENT, body: nil)
  }
 
  func emitEvent(type:String!, body: AnyObject!) {
    self.bridge.eventDispatcher.sendDeviceEventWithName("GCMEvent", body: ["type": type, "data": body])
  }
  
  func _appRegisteredWithToken(notification: NSNotification) {
    if let info = notification.userInfo as? Dictionary<String, AnyObject> {
      if let deviceToken = info["deviceToken"] as? NSData {
        self.deviceToken = deviceToken
        GGLInstanceID.sharedInstance().startWithConfig(GGLInstanceIDConfig.defaultConfig());
        self.registrationOptions = [kGGLInstanceIDRegisterAPNSOption: deviceToken,
          kGGLInstanceIDAPNSServerTypeSandboxOption:true]
        GGLInstanceID.sharedInstance().tokenWithAuthorizedEntity(gcmSenderID,
          scope: kGGLInstanceIDScopeGCM, options: self.registrationOptions, handler: self._handleGCMRegistration)
      }
    }
  }
  
  func _applicationDidEnterBackground(notification: NSNotification) {
    GCMService.sharedInstance().disconnect();
    self.connectedToGCM = false;
    self.emitEvent(GCM.ENTERED_BACKGROUND_EVENT, body: nil)
  }
  
  func _applicationDidBecomeActive(notification: NSNotification) {
    GCMService.sharedInstance().connectWithHandler({(NSError error) -> Void in
      if error != nil {
        self.emitEvent(GCM.BECAME_ACTIVE_EVENT, body: ["error": error.localizedDescription])
      } else {
        self.emitEvent(GCM.BECAME_ACTIVE_EVENT, body: nil)
      }
    })
  }
 
  @objc func register() {
    // Configure the Google context: parses the GoogleService-Info.plist, and initializes
    // the services that have entries in the file
    var configureError:NSError?
    
    GGLContext.sharedInstance().configureWithError(&configureError)
    
    if configureError != nil {
      self.emitEvent(GCM.REGISTERED_CLIENT_EVENT, body: ["error": configureError!.localizedDescription])
      return
    }
    
    var types: UIUserNotificationType = .Badge | .Alert | .Sound
    var settings: UIUserNotificationSettings = UIUserNotificationSettings( forTypes: types, categories: nil )
    UIApplication.sharedApplication().registerUserNotificationSettings( settings )
    UIApplication.sharedApplication().registerForRemoteNotifications()
    GCMService.sharedInstance().startWithConfig(GCMConfig.defaultConfig())
  }
  
  func _handleGCMRegistration(registrationToken: String!, error: NSError!) {
    if (registrationToken != nil) {
      self.registrationToken = registrationToken
      println("Registration Token: \(registrationToken)")
      let userInfo = ["registrationToken": registrationToken, "error": ""]
      self.bridge.eventDispatcher.sendDeviceEventWithName(GCM.REGISTERED_CLIENT_EVENT, body: userInfo)
    } else {
      let userInfo = ["registrationToken": "", "error": error.localizedDescription]
      self.bridge.eventDispatcher.sendDeviceEventWithName(GCM.REGISTERED_CLIENT_EVENT, body: userInfo)
    }
  }
  
  func onTokenRefresh() {
    // A rotation of the registration tokens is happening, so the app needs to request a new token.
    GGLInstanceID.sharedInstance().tokenWithAuthorizedEntity(self.gcmSenderID,
      scope: kGGLInstanceIDScopeGCM, options: nil, handler: self._handleGCMRegistration)
  }
  
 // [START on_token_refresh]
  
  func _handleMessageReceived(notification: NSNotification) {
    if let info = notification.userInfo as? Dictionary<String,AnyObject> {
      self.emitEvent(GCM.MESSAGE_EVENT, body: info)
    } else {
      self.emitEvent(GCM.MESSAGE_EVENT, body: nil)
    }
  }
}