//
//  JVRequestOperation.m
//  Jarvi
//
//  Created by AVGD-Jarvi on 17/3/9.
//  Copyright © 2017年 AVGD-Jarvi. All rights reserved.
//

#import "JVRequestOperation.h"

typedef NS_ENUM(NSInteger, JVRequestOperationState) {
    JVRequestOperationReadyState = 0,
    JVRequestOperationExecutingState,
    JVRequestOperationFinishedState,
    JVRequestOperationCancelledState
};

NSString * const JVRequestOperationDidStartNotification = @"com.jarvi.http-operation.start";
NSString * const JVRequestOperationDidFinishNotification = @"com.jarvi.http-operation.finish";

typedef void(^JVRequestOperationCompletionBlock)(NSURLRequest *request, NSHTTPURLResponse *response, NSData *data, NSError *error);

static inline NSString * JVKeyPathFromOperationState(JVRequestOperationState state) {
    switch (state) {
        case JVRequestOperationReadyState:
            return @"isReady";
            break;
        case JVRequestOperationExecutingState:
            return @"isExecuting";
            break;
        case JVRequestOperationFinishedState:
            return @"isFinished";
            break;
        default:
            return @"state";
    }
}

static inline BOOL JVOperationStateTransitionIsValid(JVRequestOperationState from, JVRequestOperationState to) {
    if (from == to) {
        return NO;
    }
    
    switch (from) {
        case JVRequestOperationReadyState:
            switch (to) {
                case JVRequestOperationExecutingState:
                    return YES;
                default:
                    return NO;
            
            }
        case JVRequestOperationExecutingState:
            switch (to) {
                case JVRequestOperationReadyState:
                    return NO;
                default:
                    return YES;
            }
        case JVRequestOperationFinishedState:
            return NO;
        default:
            return YES;
    }
}

@interface JVRequestOperation ()

@property (nonatomic, assign) JVRequestOperationState state;
@property (nonatomic, assign) BOOL isCancelled;
@property (nonatomic, strong) NSPort *port;
@property (nonatomic, strong) NSMutableData *dataAccumulator;
@property (nonatomic, copy) JVRequestOperationCompletionBlock completion;

@end

@implementation JVRequestOperation

+ (id)operationWithRequest:(NSURLRequest *)request
                completion:(void (^)(NSURLRequest *, NSHTTPURLResponse *, NSData *, NSError *))completion {
    JVRequestOperation *operation = [[JVRequestOperation alloc] initWithRequest:request];
    operation.completion = completion;
    return operation;
}

- (id)initWithRequest:(NSURLRequest *)request {
    if (self = [super init]) {
        self.request = request;
        self.runLoopModes = [NSSet setWithObjects:NSRunLoopCommonModes, nil];
        self.state = JVRequestOperationReadyState;
    }
    return self;
}

- (void)cleanup {
    for (NSString *runLoopMode in self.runLoopModes) {
        [[NSRunLoop currentRunLoop] removePort:self.port forMode:runLoopMode];
        [self.connection unscheduleFromRunLoop:[NSRunLoop currentRunLoop] forMode:runLoopMode];
    }
    CFRunLoopStop([[NSRunLoop currentRunLoop] getCFRunLoop]);
}

- (void)setState:(JVRequestOperationState)state {
    if (!JVOperationStateTransitionIsValid(self.state, state)) {
        return;
    }
    
    NSString *oldStateKey = JVKeyPathFromOperationState(self.state);
    NSString *newStateKey = JVKeyPathFromOperationState(state);
    
    [self willChangeValueForKey:oldStateKey];
    [self willChangeValueForKey:newStateKey];
    _state = state;
    [self didChangeValueForKey:oldStateKey];
    [self didChangeValueForKey:newStateKey];
    
    switch (state) {
        case JVRequestOperationExecutingState:
            [[NSNotificationCenter defaultCenter] postNotificationName:JVRequestOperationDidStartNotification object:nil];
            break;
        case JVRequestOperationFinishedState:
            [[NSNotificationCenter defaultCenter] postNotificationName:JVRequestOperationDidFinishNotification object:nil];
            break;
        default:
            break;
    }
}

- (NSString *)responseString {
    return [[NSString alloc] initWithData:self.responseBody encoding:NSUTF8StringEncoding];
}

#pragma mark - NSOperation

- (BOOL)isReady {
    return self.state == JVRequestOperationReadyState;
}

- (BOOL)isExecuting {
    return self.state == JVRequestOperationExecutingState;
}

- (BOOL)isFinished {
    return self.state == JVRequestOperationFinishedState;
}

- (void)cancel {
    self.isCancelled = YES;
    [self.connection cancel];
    [self cleanup];
}

- (BOOL)isConcurrent {
    return YES;
}

- (void)start {
    if (self.isFinished || self.isCancelled) {
        return;
    }
    
    self.state = JVRequestOperationExecutingState;
    
    self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
    self.port = [NSPort port];
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    for (NSString *runLoopMode in self.runLoopModes) {
        [self.connection scheduleInRunLoop:runLoop forMode:runLoopMode];
        [runLoop addPort:self.port forMode:runLoopMode];
    }
    
    [self.connection start];
    
    [runLoop run];
}

#pragma mark JVRequestOperation

- (void)finish {
    if (self.isCancelled) {
        return;
    }
    
    if (self.completion) {
        self.completion(self.request, self.response, self.responseBody, self.error);
    }
}

#pragma mark NSURLConnection

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    self.response = (NSHTTPURLResponse *)response;
    
    NSUInteger contentLength = MIN(MAX(llabs(response.expectedContentLength), 1024), 1024 *1024 *8);
    self.dataAccumulator = [NSMutableData dataWithCapacity:contentLength];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.dataAccumulator appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    self.state = JVRequestOperationFinishedState;
    
    self.responseBody = [NSData dataWithData:self.dataAccumulator];
    self.dataAccumulator = nil;
    
    [self performSelectorOnMainThread:@selector(finish) withObject:nil waitUntilDone:YES modes:[self.runLoopModes allObjects]];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    self.state = JVRequestOperationFinishedState;
    
    self.error = error;
    
    [self performSelectorOnMainThread:@selector(finish) withObject:nil waitUntilDone:YES modes:[self.runLoopModes allObjects]];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse {
    if ([self isCancelled]) {
        return nil;
    }
    
    return cachedResponse;
}

@end
