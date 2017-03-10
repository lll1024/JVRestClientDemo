//
//  JVRestClient.h
//  Jarvi
//
//  Created by AVGD-Jarvi on 17/3/9.
//  Copyright © 2017年 AVGD-Jarvi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JVRequestOperation.h"

@protocol JVRestClient <NSObject>
+ (NSURL *)baseURL;
@end

@interface JVRestClient : NSObject <JVRestClient>

- (NSString *)defaultValueForHeader:(NSString *)header;
- (void)setDefaultHeader:(NSString *)header value:(NSString *)value;
- (void)setAuthorizationHeaderWithToken:(NSString *)token;
- (void)clearAuthorizationHeader;

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method
                                      path:(NSString *)path
                                parameters:(NSDictionary *)parameters;

- (void)enqueueHTTPOperationWithRequest:(NSURLRequest *)request
                                success:(void (^)(id response))success
                                failure:(void (^)(NSError *error))failure;

- (void)getPath:(NSString *)path
     parameters:(NSDictionary *)parameters
        success:(void (^)(id response))success;

- (void)getPath:(NSString *)path
     parameters:(NSDictionary *)parameters
        success:(void (^)(id response))success
        failure:(void (^)(NSError *error))failure;

@end
