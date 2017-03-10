//
//  JVJSONRequestOperation.h
//  Jarvi
//
//  Created by AVGD-Jarvi on 17/3/10.
//  Copyright © 2017年 AVGD-Jarvi. All rights reserved.
//

#import "JVRequestOperation.h"


@interface JVJSONRequestOperation : JVRequestOperation

+ (id)operationWithRequset:(NSURLRequest *)request
                   success:(void (^)(id JSON))success;

+ (id)operationWithRequset:(NSURLRequest *)request
                   success:(void (^)(id JSON))success
                   failure:(void (^)(NSError *error))failure;

+ (id)operationWithRequest:(NSURLRequest *)request
     acceptableStatusCodes:(NSIndexSet *)acceptableStatusCodes
    acceptableContentTypes:(NSSet *)acceptableContentTypes
                   success:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, id  JSON))success
                   failure:(void (^)(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error))failure;

+ (NSIndexSet *)defaultAcceptableStatusCodes;
+ (NSSet *)defaultAcceptableContentTypes;

@end
