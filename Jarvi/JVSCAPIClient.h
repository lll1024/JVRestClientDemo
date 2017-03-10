//
//  JVSCAPIClient.h
//  Jarvi
//
//  Created by AVGD-Jarvi on 17/3/10.
//  Copyright © 2017年 AVGD-Jarvi. All rights reserved.
//

#import "JVRestClient.h"

extern NSString * const kJVSCClientID;
extern NSString * const kJVSCClientSecret;
extern NSString * const kJVSCBaseURLString;

@interface JVSCAPIClient : JVRestClient

+ (id)sharedClient;

@end
