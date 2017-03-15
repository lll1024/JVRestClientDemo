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
        case JVRequestOperationExecutingState:
            return @"isExecuting";
        case JVRequestOperationFinishedState:
            return @"isFinished";
        default:
            return @"state";
    }
}

static inline BOOL JVOperationStateTransitionIsValid(JVRequestOperationState fromState, JVRequestOperationState toState, BOOL isCancelled) {
    switch (fromState) {
        case JVRequestOperationReadyState:
            switch (toState) {
                case JVRequestOperationExecutingState:
                    return YES;
                case JVRequestOperationFinishedState:
                    return isCancelled;
                default:
                    return NO;
            
            }
        case JVRequestOperationExecutingState:
            switch (toState) {
                case JVRequestOperationFinishedState:
                    return YES;
                default:
                    return NO;
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
@property (nonatomic, strong) NSMutableData *dataAccumulator;
@property (nonatomic, copy) JVRequestOperationCompletionBlock completion;

@end

@implementation JVRequestOperation

+ (void) __attribute((noreturn)) networkRequestThreadEntryPoint:(id)__unused object {
    do {
        @autoreleasepool {
            [[NSRunLoop currentRunLoop] run];
        }
    } while (YES);
}

+ (NSThread *)shareRequestThread {
    static NSThread * _requestThread = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _requestThread = [[NSThread alloc] initWithTarget:self selector:@selector(networkRequestThreadEntryPoint:) object:nil];
        [_requestThread start];
    });
    
    return _requestThread;
}

+ (id)operationWithRequest:(NSURLRequest *)request
                completion:(void (^)(NSURLRequest *, NSHTTPURLResponse *, NSData *, NSError *))completion {
    JVRequestOperation *operation = [[JVRequestOperation alloc] initWithRequest:request];
    operation.completion = completion;
    
    return operation;
}

- (id)initWithRequest:(NSURLRequest *)request {
    if (self = [super init]) {
        self.request = request;
        self.runLoopModes = [NSSet setWithObject:NSRunLoopCommonModes];
        self.state = JVRequestOperationReadyState;
    }
    
    return self;
}

- (void)cleanup {
    for (NSString *runLoopMode in self.runLoopModes) {
        [self.connection unscheduleFromRunLoop:[NSRunLoop currentRunLoop] forMode:runLoopMode];
    }
    
    CFRunLoopStop([[NSRunLoop currentRunLoop] getCFRunLoop]);
}

- (void)setState:(JVRequestOperationState)state {
    if (!JVOperationStateTransitionIsValid(self.state, state, [self isCancelled])) {
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
            [[NSNotificationCenter defaultCenter] postNotificationName:JVRequestOperationDidStartNotification object:self];
            break;
        case JVRequestOperationFinishedState:
            [[NSNotificationCenter defaultCenter] postNotificationName:JVRequestOperationDidFinishNotification object:self];
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

- (BOOL)isConcurrent {
    return YES;
}

- (void)start {
    if ([self isReady]) {
        self.state = JVRequestOperationExecutingState;
        [self performSelector:@selector(operationDidStart) onThread:[[self class] shareRequestThread] withObject:nil waitUntilDone:NO modes:[self.runLoopModes allObjects]];
    }
}

- (void)operationDidStart {
    if ([self isCancelled]) {
        [self finish];
    } else {
        self.connection = [[NSURLConnection alloc] initWithRequest:self.request delegate:self startImmediately:NO];
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        for (NSString *runLoopMode in self.runLoopModes) {
            [self.connection scheduleInRunLoop:runLoop forMode:runLoopMode];
        }
        
        [self.connection start];
    }
}

- (void)finish {
    if (self.isCancelled) {
        return;
    }
    
    if (self.completion) {
        self.completion(self.request, self.response, self.responseBody, self.error);
    }
}

- (void)cancel {
    if (![self isFinished] && ![self isCancelled]) {
        [self willChangeValueForKey:@"isCancelled"];
        _isCancelled = YES;
        [super cancel];
        [self didChangeValueForKey:@"isCancelled"];
        
        [self performSelector:@selector(cancelConnection) onThread:[[self class] shareRequestThread] withObject:nil waitUntilDone:NO modes:[self.runLoopModes allObjects]];
    }
}

- (void)cancelConnection {
    if (self.connection) {
        [self.connection cancel];
        
        NSDictionary *userInfo = nil;
        if ([self.request URL]) {
            userInfo = [NSDictionary dictionaryWithObject:[self.request URL] forKey:NSURLErrorFailingURLErrorKey];
        }
        [self performSelector:@selector(connection:didFailWithError:) withObject:self.connection withObject:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:userInfo]];
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
