//
//  JVSCAPIClient.m
//  Jarvi
//
//  Created by AVGD-Jarvi on 17/3/10.
//  Copyright © 2017年 AVGD-Jarvi. All rights reserved.
//

#import "JVSCAPIClient.h"

NSString * const kJVSCBaseURLString = @"http://wthrcdn.etouch.cn";

@implementation JVSCAPIClient

+ (id)sharedClient {
    static JVSCAPIClient *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[self alloc] init];
    });
    
    return _sharedClient;
}

- (id)init {
    if (self = [super init]) {
        
        //[self setDefaultHeader:@"Authorization" value:@"..."];
        //...
    }
    return self;
}

+ (NSURL *)baseURL {
    return [NSURL URLWithString:kJVSCBaseURLString];
}

@end
