#import "SEGHTTPClient.h"
#import "NSData+SEGGZIP.h"
#import "SEGAnalyticsUtils.h"


@implementation ByteGainHTTPClient

+ (NSMutableURLRequest * (^)(NSURL *))defaultRequestFactory
{
    return ^(NSURL *url) {
        return [NSMutableURLRequest requestWithURL:url];
    };
}

+ (NSString *)authorizationHeader:(NSString *)writeKey
{
    NSString *rawHeader = [writeKey stringByAppendingString:@":"];
    NSData *userPasswordData = [rawHeader dataUsingEncoding:NSUTF8StringEncoding];
    return [userPasswordData base64EncodedStringWithOptions:0];
}


- (instancetype)initWithRequestFactory:(ByteGainRequestFactory)requestFactory
                           withApiBase:(NSURL *) apiBase
                          withTestMode:(Boolean) testMode
{
    if (self = [self init]) {
        if (requestFactory == nil) {
            self.requestFactory = [ByteGainHTTPClient defaultRequestFactory];
        } else {
            self.requestFactory = requestFactory;
        }
        _sessionsByWriteKey = [NSMutableDictionary dictionary];
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        config.HTTPAdditionalHeaders = @{ @"Accept-Encoding" : @"gzip" };
        _genericSession = [NSURLSession sessionWithConfiguration:config];
        _apiBase = apiBase;
        _testMode = testMode;
    }
    return self;
}

- (NSURLSession *)sessionForWriteKey:(NSString *)writeKey
{
    NSURLSession *session = self.sessionsByWriteKey[writeKey];
    if (!session) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSMutableDictionary *headers = [@{
                                          @"Accept-Encoding" : @"gzip",
                                          @"Content-Encoding" : @"gzip",
                                          @"Content-Type" : @"application/json",
                                          @"Authorization" : [@"Basic " stringByAppendingString:[[self class] authorizationHeader:writeKey]],
                                        } mutableCopy];
        if (_testMode) {
            headers[@"X-ByteGainTestMode"] = @"true";
        }
        config.HTTPAdditionalHeaders = headers;
        session = [NSURLSession sessionWithConfiguration:config];
        self.sessionsByWriteKey[writeKey] = session;
    }
    return session;
}

- (void)dealloc
{
    for (NSURLSession *session in self.sessionsByWriteKey.allValues) {
        [session finishTasksAndInvalidate];
    }
    [self.genericSession finishTasksAndInvalidate];
}


- (NSURLSessionUploadTask *)upload:(NSDictionary *)batch forWriteKey:(NSString *)writeKey completionHandler:(void (^)(BOOL retry, JSON_DICT _Nullable response))completionHandler
{
    //    batch = ByteGainCoerceDictionary(batch);
    NSURLSession *session = [self sessionForWriteKey:writeKey];

    NSURL *url = [_apiBase URLByAppendingPathComponent:@"batch"];
    NSMutableURLRequest *request = self.requestFactory(url);

    // This is a workaround for an IOS 8.3 bug that causes Content-Type to be incorrectly set
    [request addValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [request setHTTPMethod:@"POST"];

    NSError *error = nil;
    NSException *exception = nil;
    NSData *payload = nil;
    @try {
        payload = [NSJSONSerialization dataWithJSONObject:batch options:0 error:&error];
    }
    @catch (NSException *exc) {
        exception = exc;
    }
    if (error || exception) {
        ByteGainLog(@"Error serializing JSON for batch upload %@", error);
        completionHandler(NO, nil); // Don't retry this batch.
        return nil;
    }
    NSData *gzippedPayload = [payload seg_gzippedData];

    NSURLSessionUploadTask *task = [session uploadTaskWithRequest:request
                                                         fromData:gzippedPayload
                                                completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError *_Nullable error) {
        if (error) {
            ByteGainLog(@"Error uploading request %@.", error);
            completionHandler(YES, nil);
            return;
        }
        if (response == nil) {
            ByteGainLog(@"upload response for /v1/batch is nil");
            completionHandler(NO, nil);
            return;
        }

        NSInteger code = ((NSHTTPURLResponse *)response).statusCode;
        if (code < 300) {
            // 2xx response codes.

            NSError *jsonError = nil;
            id responseJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (jsonError != nil) {
                ByteGainLog(@"Error deserializing response body %@.", jsonError);
                completionHandler(NO, nil);
                return;
            }
            completionHandler(NO, responseJson);
            return;
        }
        if (code < 400) {
            // 3xx response codes.
            ByteGainLog(@"Server responded with unexpected HTTP code %d.", code);
            completionHandler(YES, nil);
            return;
        }
        if (code < 500) {
            // 4xx response codes.
            ByteGainLog(@"Server rejected payload with HTTP code %d.", code);
            completionHandler(NO, nil);
            return;
        }

        // 5xx response codes.
        ByteGainLog(@"Server error with HTTP code %d.", code);
        completionHandler(YES, nil);
    }];
    [task resume];
    return task;
}

- (NSURLSessionDataTask *)settingsForWriteKey:(NSString *)writeKey completionHandler:(void (^)(BOOL success, JSON_DICT _Nullable settings))completionHandler
{
    return nil;
    /*
    NSURLSession *session = self.genericSession;

    NSURL *url = [BYTEGAIN_CDN_BASE URLByAppendingPathComponent:[NSString stringWithFormat:@"/projects/%@/settings", writeKey]];
    NSMutableURLRequest *request = self.requestFactory(url);
    [request setHTTPMethod:@"GET"];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        if (error != nil) {
            ByteGainLog(@"Error fetching settings %@.", error);
            completionHandler(NO, nil);
            return;
        }

        NSInteger code = ((NSHTTPURLResponse *)response).statusCode;
        if (code > 300) {
            ByteGainLog(@"Server responded with unexpected HTTP code %d.", code);
            completionHandler(NO, nil);
            return;
        }

        NSError *jsonError = nil;
        id responseJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError != nil) {
            ByteGainLog(@"Error deserializing response body %@.", jsonError);
            completionHandler(NO, nil);
            return;
        }

        completionHandler(YES, responseJson);
    }];
    [task resume];
    return task;
     */
}

- (NSURLSessionDataTask *)attributionWithWriteKey:(NSString *)writeKey forDevice:(JSON_DICT)context completionHandler:(void (^)(BOOL success, JSON_DICT _Nullable properties))completionHandler;

{
    return nil;
    /*
    NSURLSession *session = [self sessionForWriteKey:writeKey];

    NSURL *url = [MOBILE_SERVICE_BASE URLByAppendingPathComponent:@"/attribution"];
    NSMutableURLRequest *request = self.requestFactory(url);
    [request setHTTPMethod:@"POST"];

    NSError *error = nil;
    NSException *exception = nil;
    NSData *payload = nil;
    @try {
        payload = [NSJSONSerialization dataWithJSONObject:context options:0 error:&error];
    }
    @catch (NSException *exc) {
        exception = exc;
    }
    if (error || exception) {
        ByteGainLog(@"Error serializing context to JSON %@", error);
        completionHandler(NO, nil);
        return nil;
    }
    NSData *gzippedPayload = [payload seg_gzippedData];

    NSURLSessionUploadTask *task = [session uploadTaskWithRequest:request fromData:gzippedPayload completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        if (error) {
            ByteGainLog(@"Error making request %@.", error);
            completionHandler(NO, nil);
            return;
        }

        NSInteger code = ((NSHTTPURLResponse *)response).statusCode;
        if (code > 300) {
            ByteGainLog(@"Server responded with unexpected HTTP code %d.", code);
            completionHandler(NO, nil);
            return;
        }

        NSError *jsonError = nil;
        id responseJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (jsonError != nil) {
            ByteGainLog(@"Error deserializing response body %@.", jsonError);
            completionHandler(NO, nil);
            return;
        }

        completionHandler(YES, responseJson);
    }];
    [task resume];
    return task;
     */
}

@end
