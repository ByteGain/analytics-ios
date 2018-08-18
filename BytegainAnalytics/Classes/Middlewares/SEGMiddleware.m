//
//  ByteGainMiddleware.m
//  Analytics
//
//  Created by Tony Xiao on 9/19/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import "SEGUtils.h"
#import "SEGMiddleware.h"


@implementation ByteGainBlockMiddleware

- (instancetype)initWithBlock:(ByteGainMiddlewareBlock)block
{
    if (self = [super init]) {
        _block = block;
    }
    return self;
}

- (void)context:(ByteGainContext *)context next:(ByteGainMiddlewareNext)next
{
    self.block(context, next);
}

@end


@implementation ByteGainMiddlewareRunner

- (instancetype)initWithMiddlewares:(NSArray<id<ByteGainMiddleware>> *_Nonnull)middlewares
{
    if (self = [super init]) {
        _middlewares = middlewares;
    }
    return self;
}

- (void)run:(ByteGainContext *_Nonnull)context callback:(RunMiddlewaresCallback _Nullable)callback
{
    [self runMiddlewares:self.middlewares context:context callback:callback];
}

// TODO: Maybe rename ByteGainContext to ByteGainEvent to be a bit more clear?
// We could also use some sanity check / other types of logging here.
- (void)runMiddlewares:(NSArray<id<ByteGainMiddleware>> *_Nonnull)middlewares
               context:(ByteGainContext *_Nonnull)context
              callback:(RunMiddlewaresCallback _Nullable)callback
{
    BOOL earlyExit = context == nil;
    if (middlewares.count == 0 || earlyExit) {
        if (callback) {
            callback(earlyExit, middlewares);
        }
        return;
    }

    [middlewares[0] context:context next:^(ByteGainContext *_Nullable newContext) {
        NSArray *remainingMiddlewares = [middlewares subarrayWithRange:NSMakeRange(1, middlewares.count - 1)];
        [self runMiddlewares:remainingMiddlewares context:newContext callback:callback];
    }];
}

@end
