//
//  JVRestClient.m
//  Jarvi
//
//  Created by AVGD-Jarvi on 17/3/9.
//  Copyright © 2017年 AVGD-Jarvi. All rights reserved.
//

#import "JVRestClient.h"
#import "JVJSONRequestOperation.h"

static NSStringEncoding const kJVRestClientStringEncoding = NSUTF8StringEncoding;

@interface JVRestClient ()
@property (nonatomic, strong) NSMutableDictionary *defaultHeaders;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@end

@implementation JVRestClient

- (id)init {
    if (self = [super init]) {
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.operationQueue.maxConcurrentOperationCount = NSOperationQueueDefaultMaxConcurrentOperationCount;
        
        self.defaultHeaders = [NSMutableDictionary dictionary];
    }
    return self;
}

+ (NSURL *)baseURL {
    return nil;
}

- (NSString *)defaultValueForHeader:(NSString *)header {
    return [self.defaultHeaders valueForKey:header];
}

- (void)setDefaultHeader:(NSString *)header value:(NSString *)value {
    [self.defaultHeaders setObject:value forKey:header];
}

- (void)setAuthorizationHeaderWithToken:(NSString *)token {
    [self setDefaultHeader:@"Authorization" value:token];
}

- (void)clearAuthorizationHeader {
    [self.defaultHeaders removeObjectForKey:@"Authorization"];
}

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithDictionary:self.defaultHeaders];
    NSURL *url = [NSURL URLWithString:path relativeToURL:[[self class] baseURL]];

    if (parameters) {
        NSMutableArray *mutableParameterComponents = [NSMutableArray array];
        for (id key in [parameters allKeys]) {
            NSString *component = [NSString stringWithFormat:@"%@=%@", [key stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]], [[parameters valueForKey:key] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]]];
            [mutableParameterComponents addObject:component];
        }
        NSString *queryString = [mutableParameterComponents componentsJoinedByString:@"&"];
        
        if ([method isEqualToString:@"GET"]) {
            url = [NSURL URLWithString:[[url absoluteString] stringByAppendingFormat:[path rangeOfString:@"?"].location == NSNotFound ? @"?%@" : @"&%@", queryString]];
        } else {
            NSString *charset = (NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(kJVRestClientStringEncoding));
            [headers setObject:[NSString stringWithFormat:@"application/x-www-form-urlencoded; charset=%@", charset] forKey:@"Content-Type"];
            [request setHTTPBody:[queryString dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    
    [request setURL:url];
    [request setHTTPMethod:method];
    [request setHTTPShouldHandleCookies:NO];
    [request setAllHTTPHeaderFields:headers];
    
    return request;
}

- (void)enqueueHTTPOperationWithRequest:(NSURLRequest *)request success:(void (^)(id))success failure:(void (^)(NSError *))failure {
    if ([request URL] == nil || [[request URL] isEqual:[NSNull null]]) {
        return;
    }
    
    JVRequestOperation *operation = [JVJSONRequestOperation operationWithRequset:request success:success failure:failure];
    [self.operationQueue addOperation:operation];
}

- (void)getPath:(NSString *)path parameters:(NSDictionary *)parameters success:(void (^)(id))success {
    NSURLRequest *request = [self requestWithMethod:@"GET" path:path parameters:parameters];
    [self enqueueHTTPOperationWithRequest:request success:success failure:nil];
}

- (void)getPath:(NSString *)path parameters:(NSDictionary *)parameters success:(void (^)(id))success failure:(void (^)(NSError *))failure {
    NSURLRequest *request = [self requestWithMethod:@"GET" path:path parameters:parameters];
    [self enqueueHTTPOperationWithRequest:request success:success failure:failure];
}

@end
