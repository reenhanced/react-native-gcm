//
//  GCMManager.m
//
//  Created by Christian Sullivan on 5/28/15.
//  Copyright (c) 2015 Bodhi5 Inc. All rights reserved.
//

#import "RCTBridgeModule.h"

@interface RCT_EXTERN_MODULE(GCM, NSObject)

RCT_EXTERN_METHOD(register:(NSDictionary *)permissions)
RCT_EXTERN_METHOD(unregister:(RCTResponseSenderBlock *)callback)
RCT_EXTERN_METHOD(setAppBadge:(int)val advance:(BOOL)advance withCallback:(RCTResponseSenderBlock *)callback)
RCT_EXTERN_METHOD(getAppBadge:(RCTResponseSenderBlock *)callback)
RCT_EXTERN_METHOD(sendMessage:(NSDictionary *)data)
RCT_EXTERN_METHOD(topicSubscribe:(NSString *)topic withCallback:(RCTResponseSenderBlock *)callback)
RCT_EXTERN_METHOD(topicUnsubscribe:(NSString *)topic withCallback:(RCTResponseSenderBlock *)callback)

@end
