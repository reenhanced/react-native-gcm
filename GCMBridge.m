//
//  GCMManager.m
//  techtime
//
//  Created by Christian Sullivan on 5/28/15.
//  Copyright (c) 2015 Facebook. All rights reserved.
//

#import "RCTBridge.h"

@interface RCT_EXTERN_MODULE(GCM, NSObject)

RCT_EXTERN_METHOD(register)
RCT_EXTERN_METHOD(sendMessage:(NSDictionary *)data)
RCT_EXTERN_METHOD(topicSubscribe:(NSString *)topic)
RCT_EXTERN_METHOD(topicUnsubscribe:(NSString *)topic)

@end