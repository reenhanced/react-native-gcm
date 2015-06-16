//
//  GCM.swift
//  techtime
//
//  Created by Christian Sullivan on 5/28/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

import Foundation

let GCMRegisteredForRemoteNotifications = "GCMAppRegisteredForRemoteNotifications"
let GCMReceivedRemoteNotification = "GCMAppReceivedRemoteNotification"

extension AppDelegate {
  func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
    let userInfo: [String: AnyObject]!  = ["deviceToken": deviceToken]
    NSNotificationCenter.defaultCenter().postNotificationName(GCMRegisteredForRemoteNotifications, object: nil, userInfo: userInfo)
  }
  
  func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
    let userInfo = ["deviceToken": NSData(), "error": error]
    NSNotificationCenter.defaultCenter().postNotificationName(GCMRegisteredForRemoteNotifications, object: nil, userInfo: userInfo)
  }
  
  func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
    print("%v", userInfo)
    NSNotificationCenter.defaultCenter().postNotificationName(GCMReceivedRemoteNotification, object: nil, userInfo: userInfo)
    completionHandler(UIBackgroundFetchResult.NoData)
  }
}


let EmptyResponse = [String:AnyObject]()

@objc(GCM)
class GCM: NSObject, GGLInstanceIDDelegate {
  

  static let CONNECTION_EVENT = "connection"
  static let DISCONNECT_EVENT = "disconnect"
  static let REGISTERED_CLIENT_EVENT = "registeredClient"
  static let TOKEN_REFRESH_EVENT = "tokenRefresh"
  static let ENTERED_BACKGROUND_EVENT = "enteredBackground"
  static let BECAME_ACTIVE_EVENT = "becameActive"
  static let MESSAGE_EVENT = "message"
  static let TOPIC_SUBSCRIBE_EVENT = "topicSubscribe"
  static let TOPIC_UNSUBSCRIBE_EVENT = "topicUnsubscribe"
  
  
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

    self.initObservers()
  }
  
  func initObservers() {
    let nc: NSNotificationCenter = NSNotificationCenter.defaultCenter();
    nc.addObserver(self, selector: "_appDidEnterBackground:", name: UIApplicationDidEnterBackgroundNotification, object: nil)
    nc.addObserver(self, selector: "_appDidBecomeActive:", name: UIApplicationDidBecomeActiveNotification, object: nil)
    nc.addObserver(self, selector: "_appDidRegisterForRemoteNotifications:", name: GCMRegisteredForRemoteNotifications, object: nil)
    nc.addObserver(self, selector: "_appDidReceiveRemoteNotification:", name: GCMReceivedRemoteNotification, object: nil)
  }
  
  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self)
  }
 
  func emitEvent(type:String!, body: AnyObject!) {
    self.bridge.eventDispatcher.sendDeviceEventWithName("GCMEvent", body: ["type": type, "data": body])
  }
  
  func _appDidReceiveRemoteNotification(notification: NSNotification) {
    if let info = notification.userInfo as? Dictionary<String,AnyObject> {
      self.emitEvent(GCM.MESSAGE_EVENT, body: info)
    } else {
      self.emitEvent(GCM.MESSAGE_EVENT, body: EmptyResponse)
    }
  }
  
  func _appDidRegisterForRemoteNotifications(notification: NSNotification) {
    if let info = notification.userInfo as? Dictionary<String, AnyObject> {
      if let token = info["deviceToken"] as? NSData {
        self.deviceToken = token
        GGLInstanceID.sharedInstance().startWithConfig(GGLInstanceIDConfig.defaultConfig());
        
        self.registrationOptions = [kGGLInstanceIDRegisterAPNSOption: token,
          kGGLInstanceIDAPNSServerTypeSandboxOption:true]
        
        GGLInstanceID.sharedInstance().tokenWithAuthorizedEntity(self.gcmSenderID,
          scope: kGGLInstanceIDScopeGCM, options: self.registrationOptions, handler: self._handleGCMRegistration)
      }
    }
  }
  
  func _appDidEnterBackground(notification: NSNotification) {
    GCMService.sharedInstance().disconnect();
    self.connectedToGCM = false;
    self.emitEvent(GCM.ENTERED_BACKGROUND_EVENT, body: EmptyResponse)
  }
  
  func _appDidBecomeActive(notification: NSNotification) {
    GCMService.sharedInstance().connectWithHandler({(NSError error) -> Void in
      if error != nil {
        self.emitEvent(GCM.BECAME_ACTIVE_EVENT, body: ["error": error.localizedDescription])
      } else {
        self.connectedToGCM = true
        self.emitEvent(GCM.BECAME_ACTIVE_EVENT, body: EmptyResponse)
      }
    })
  }
  
  func _handleGCMRegistration(registrationToken: String!, error: NSError!) {
    print("token: %v\nerror: %v", registrationToken, error)
    if (registrationToken != nil) {
      self.registrationToken = registrationToken
      let userInfo = [ "registrationToken": registrationToken! ]
      self.emitEvent(GCM.REGISTERED_CLIENT_EVENT, body: userInfo)
    } else {
      let userInfo = ["error": error.localizedDescription]
      self.emitEvent(GCM.REGISTERED_CLIENT_EVENT, body: userInfo)
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
      self.emitEvent(GCM.MESSAGE_EVENT, body: EmptyResponse)
    }
  }
  
  @objc
  func register(permissions: NSDictionary?) {
    // Configure the Google context: parses the GoogleService-Info.plist, and initializes
    // the services that have entries in the file
    var configureError:NSError?
    
    GGLContext.sharedInstance().configureWithError(&configureError)
    self.gcmSenderID = GGLContext.sharedInstance().configuration.gcmSenderID
    
    if configureError != nil {
      self.emitEvent(GCM.REGISTERED_CLIENT_EVENT, body: ["error": configureError!.localizedDescription])
      return
    }
    
    var types: UIUserNotificationType = []
    
    if (permissions != nil) {
      if (permissions!["alert"] != nil) {
        types.insert(UIUserNotificationType.Alert)
      }
      if (permissions!["badge"] != nil) {
        types.insert(UIUserNotificationType.Badge)
      }
      if (permissions!["sound"] != nil) {
        types.insert(UIUserNotificationType.Sound)
      }
    } else {
      types = [UIUserNotificationType.Alert, UIUserNotificationType.Badge, UIUserNotificationType.Sound]
    }
    
    let settings: UIUserNotificationSettings = UIUserNotificationSettings( forTypes: types, categories: nil )
    UIApplication.sharedApplication().registerUserNotificationSettings( settings )
    UIApplication.sharedApplication().registerForRemoteNotifications()
    GCMService.sharedInstance().startWithConfig(GCMConfig.defaultConfig())
  }
  
  @objc
  func unregister(callback: RCTResponseSenderBlock) {
    GGLInstanceID.sharedInstance().stopAllRequests()  
    GGLInstanceID.sharedInstance().deleteTokenWithAuthorizedEntity(self.gcmSenderID, scope: kGGLInstanceIDScopeGCM, handler: { (NSError error) -> Void in
      if (error != nil ) {
        callback([["error": "Unable to unregister: \(error.localizedDescription) Make sure you have registerd first.'", "code": error.code]])
        return
      }
      callback([["success": true]])
    })
  }
  
  @objc
  func setAppBadge(val: Int, advance: Bool, withCallback callback: RCTResponseSenderBlock) {
    print("%v", val)
    UIApplication.sharedApplication().applicationIconBadgeNumber = (advance) ? UIApplication.sharedApplication().applicationIconBadgeNumber.advancedBy(val) : val;
    callback([UIApplication.sharedApplication().applicationIconBadgeNumber])
  }
 
  @objc
  func getAppBadge(callback: RCTResponseSenderBlock) {
    callback([UIApplication.sharedApplication().applicationIconBadgeNumber])
  }
  
  @objc
  func stopAllRequests() {
    GGLInstanceID.sharedInstance().stopAllRequests()
  }
  
  @objc
  func sendMessage(data: [String:AnyObject]!) {
    let msg = data["message"] as! [String:AnyObject]
    let to = data["to"] as! String
    let ttl = data["ttl"] as? Int64
    let id = data["id"] as! String
   
    if (ttl != nil) {
      GCMService.sharedInstance().sendMessage(msg, to: to, timeToLive: ttl!, withId: id)
      return
    }
    GCMService.sharedInstance().sendMessage(msg, to: to, withId: id)
  }
  
  
  @objc
  func topicSubscribe(topic: String!, withCallback callback: RCTResponseSenderBlock) {
    // If the app has a registration token and is connected to GCM, proceed to subscribe to the
    // topic
    if(self.registrationToken != nil) {
      GCMPubSub.sharedInstance().subscribeWithToken(self.registrationToken, topic: topic,
        options: nil, handler:
        {(NSError error) -> Void in
          if (error != nil) {
            // Treat the "already subscribed" error more gently
            if error.code == 3001 {
                callback([["error": "Already subscribed to \(topic) : \(error.localizedDescription)"]])
            } else {
                callback([["error": "Subscription failed: \(error.localizedDescription)"]])
            }
          } else {
              callback([["success": true, "message": "Subscribed to \(topic))"]])
          }
      })
      return
    }
    callback([["error": "Not connected to GCM"]])
  }
  
  @objc
  func topicUnsubscribe(topic: String!, withCallback callback: RCTResponseSenderBlock) {
    // If the app has a registration token and is connected to GCM, proceed to subscribe to the
    // topic
    if(self.registrationToken != nil) {
      GCMPubSub.sharedInstance().unsubscribeWithToken(self.registrationToken, topic: topic,
        options: nil, handler: {(NSError error) -> Void in
          if (error != nil) {
            // Treat the "already subscribed" error more gently
            if error.code == 3001 {
                callback([["error": "Already subscribed to \(topic) : \(error.localizedDescription)"]])
            } else {
                callback([["error": "Subscription failed: \(error.localizedDescription)"]])
            }
          } else {
              callback([["success": true, "message": "Subscribed to \(topic))"]])
          }
      })
      return
    }
    callback([["error": "Not connected to GCM"]])
  }
}