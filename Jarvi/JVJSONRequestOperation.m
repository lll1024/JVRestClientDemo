//
//  JVJSONRequestOperation.m
//  Jarvi
//
//  Created by AVGD-Jarvi on 17/3/10.
//  Copyright © 2017年 AVGD-Jarvi. All rights reserved.
//

#import "JVJSONRequestOperation.h"

@implementation JVJSONRequestOperation

+ (id)operationWithRequset:(NSURLRequest *)request
                   success:(void (^)(id JSON))success
{
    return [self operationWithRequset:request success:success failure:nil];
}

+ (id)operationWithRequset:(NSURLRequest *)request
                   success:(void (^)(id JSON))success
                   failure:(void (^)(NSError *))failure
{
    return [self operationWithRequest:request acceptableStatusCodes:[self defaultAcceptableStatusCodes] acceptableContentTypes:[self defaultAcceptableContentTypes] success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
        if (success) {
            success(JSON);
        }
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
        if (failure) {
            failure(error);
        }
    }];
}

+ (id)operationWithRequest:(NSURLRequest *)request
     acceptableStatusCodes:(NSIndexSet *)acceptableStatusCodes
    acceptableContentTypes:(NSSet *)acceptableContentTypes
                   success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, id JSON))success
                   failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure
{
    return [self operationWithRequest:request completion:^(NSURLRequest *request, NSHTTPURLResponse *response, NSData *data, NSError *error) {
        BOOL statusCodeAcceptable = [acceptableStatusCodes containsIndex:[response statusCode]];
        BOOL contentTypeAcceptable = [acceptableContentTypes containsObject:[response MIMEType]];
        if (!statusCodeAcceptable || !contentTypeAcceptable) {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            [userInfo setValue:[NSHTTPURLResponse localizedStringForStatusCode:[response statusCode]] forKey:NSLocalizedDescriptionKey];
            [userInfo setValue:[request URL] forKey:NSURLErrorDomain];
            
            error = [[NSError alloc] initWithDomain:NSURLErrorDomain code:[response statusCode] userInfo:userInfo];
        }
        
        if (error) {
            if (failure) {
                failure(request, response, error);
            }
        } else {
            id JSON = nil;
            
            JSON = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (success) {
                success(request, response, JSON);
            }
        }
    }];
}

+ (NSIndexSet *)defaultAcceptableStatusCodes {
    return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];
}

+ (NSSet *)defaultAcceptableContentTypes {
    return [NSSet setWithObjects:@"application/json", @"application/x-javascript", @"text/javascript", @"text/x-javascript", @"text/x-json", @"text/json", @"text/plain", nil];
}

@end
