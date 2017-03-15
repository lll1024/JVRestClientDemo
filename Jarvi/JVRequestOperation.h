//
//  JVRequestOperation.h
//  Jarvi
//
//  Created by AVGD-Jarvi on 17/3/9.
//  Copyright © 2017年 AVGD-Jarvi. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const JVRequestOperationDidStartNotification;
extern NSString * const JVRequestOperationDidFinishNotification;

@interface JVRequestOperation : NSOperation<NSURLConnectionDelegate, NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSSet *runLoopModes;
@property (nonatomic, strong) NSURLRequest *request;
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, strong) NSData *responseBody;
@property (nonatomic, strong) NSString *responseString;

+ (id)operationWithRequest:(NSURLRequest *)request
                completion:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSData *data, NSError *error))completion;

- (void)pause;

- (BOOL)isPaused;

- (void)resume;

@end
