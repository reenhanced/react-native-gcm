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
  static let TOPIC_SUBSCRIBE_EVENT = "topicSubscribe"
  static let TOPIC_UNSUBSCRIBE_EVENT = "topicUnsubscribe"
  
  
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
  
  class func appDidRegisterForRemoteNotificationsWithDeviceToken(deviceToken: NSData!, error: NSError! ) {
    let userInfo: [String: AnyObject]!
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

    self.initObservers()
  }
  
  func initObservers() {
    let nc: NSNotificationCenter = NSNotificationCenter.defaultCenter();
    nc.addObserver(self, selector: "_appDidEnterBackground:", name: UIApplicationDidEnterBackgroundNotification, object: nil)
    nc.addObserver(self, selector: "_appDidBecomeActive:", name: UIApplicationDidBecomeActiveNotification, object: nil)
    
    nc.addObserver(self, selector: "_appRegisteredWithToken:", name: GCM_RECEIVED_DEVICE_TOKEN_EVENT, object: nil)
    nc.addObserver(self, selector: "_handleMessageReceived:", name: GCM_MESSAGE_RECEIVED_EVENT, object: nil)
  }
  
  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self)
    self.emitEvent(GCM.DESTRUCT_EVENT, body: ["message: "])
  }
 
  func emitEvent(type:String!, body: AnyObject!) {
    self.bridge.eventDispatcher.sendDeviceEventWithName("GCMEvent", body: ["type": type, "data": body])
  }
  
  func _appRegisteredWithToken(notification: NSNotification) {
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
    self.emitEvent(GCM.ENTERED_BACKGROUND_EVENT, body: nil)
  }
  
  func _appDidBecomeActive(notification: NSNotification) {
    GCMService.sharedInstance().connectWithHandler({(NSError error) -> Void in
      if error != nil {
        self.emitEvent(GCM.BECAME_ACTIVE_EVENT, body: ["error": error.localizedDescription])
      } else {
        self.connectedToGCM = true
        self.emitEvent(GCM.BECAME_ACTIVE_EVENT, body: nil)
      }
    })
  }
  
  func _handleGCMRegistration(registrationToken: String!, error: NSError!) {
    if (registrationToken != nil) {
      self.registrationToken = registrationToken
      println("Registration Token: \(registrationToken)")
      let userInfo = ["registrationToken": registrationToken]
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
      self.emitEvent(GCM.MESSAGE_EVENT, body: nil)
    }
  }
  
  @objc func register() {
    // Configure the Google context: parses the GoogleService-Info.plist, and initializes
    // the services that have entries in the file
    var configureError:NSError?
    
    GGLContext.sharedInstance().configureWithError(&configureError)
    self.gcmSenderID = GGLContext.sharedInstance().configuration.gcmSenderID
    
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
  func topicSubscribe(topic: String!) {
    // If the app has a registration token and is connected to GCM, proceed to subscribe to the
    // topic
    if(self.registrationToken != nil) {
      GCMPubSub.sharedInstance().subscribeWithToken(self.registrationToken, topic: topic,
        options: nil, handler: {(NSError error) -> Void in
          if (error != nil) {
            // Treat the "already subscribed" error more gently
            if error.code == 3001 {
              self.emitEvent(GCM.TOPIC_SUBSCRIBE_EVENT,
                body: ["error": "Already subscribed to \(topic) : \(error.localizedDescription)"])
            } else {
              self.emitEvent(GCM.TOPIC_SUBSCRIBE_EVENT,
                body: ["error": "Subscription failed: \(error.localizedDescription)"])
            }
          } else {
            self.emitEvent(GCM.TOPIC_SUBSCRIBE_EVENT,
              body: ["success": true, "message": "Subscribed to \(topic))"])
          }
      })
      return
    }
    self.emitEvent(GCM.TOPIC_SUBSCRIBE_EVENT, body: ["error": "Not connected to GCM"])
  }
  
  @objc
  func topicUnsubscribe(topic: String!) {
    // If the app has a registration token and is connected to GCM, proceed to subscribe to the
    // topic
    if(self.registrationToken != nil) {
      GCMPubSub.sharedInstance().unsubscribeWithToken(self.registrationToken, topic: topic,
        options: nil, handler: {(NSError error) -> Void in
          if (error != nil) {
            // Treat the "already subscribed" error more gently
            if error.code == 3001 {
              self.emitEvent(GCM.TOPIC_UNSUBSCRIBE_EVENT,
                body: ["error": "Already subscribed to \(topic) : \(error.localizedDescription)"])
            } else {
              self.emitEvent(GCM.TOPIC_UNSUBSCRIBE_EVENT,
                body: ["error": "Subscription failed: \(error.localizedDescription)"])
            }
          } else {
            self.emitEvent(GCM.TOPIC_UNSUBSCRIBE_EVENT,
              body: ["success": true, "message": "Subscribed to \(topic))"])
          }
      })
      return
    }
    self.emitEvent(GCM.TOPIC_UNSUBSCRIBE_EVENT, body: ["error": "Not connected to GCM"])
  }
}