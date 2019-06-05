#include <sys/sysctl.h>

#import <UIKit/UIKit.h>
#import "SEGAnalytics.h"
#import "SEGAnalyticsUtils.h"
#import "SEGSegmentIntegration.h"
#import "SEGReachability.h"
#import "SEGHTTPClient.h"
#import "SEGStorage.h"

#if TARGET_OS_IOS
#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#endif

NSString *const ByteGainSegmentDidSendRequestNotification = @"SegmentDidSendRequest";
NSString *const ByteGainSegmentRequestDidSucceedNotification = @"SegmentRequestDidSucceed";
NSString *const ByteGainSegmentRequestDidFailNotification = @"SegmentRequestDidFail";

NSString *const ByteGainAdvertisingClassIdentifier = @"ASIdentifierManager";
NSString *const ByteGainADClientClass = @"ADClient";

NSString *const ByteGainUserIdKey = @"ByteGainUserId";
NSString *const ByteGainQueueKey = @"ByteGainQueue";
NSString *const ByteGainTraitsKey = @"ByteGainTraits";

NSString *const kByteGainUserIdFilename = @"segmentio.userId";
NSString *const kByteGainQueueFilename = @"segmentio.queue.plist";
NSString *const kByteGainTraitsFilename = @"segmentio.traits.plist";

NSString *const kResponseIdKey = @"responseId";

static NSString *GetDeviceModel()
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char result[size];
    sysctlbyname("hw.machine", result, &size, NULL, 0);
    NSString *results = [NSString stringWithCString:result encoding:NSUTF8StringEncoding];
    return results;
}

static BOOL GetAdTrackingEnabled()
{
    BOOL result = NO;
    Class advertisingManager = NSClassFromString(ByteGainAdvertisingClassIdentifier);
    SEL sharedManagerSelector = NSSelectorFromString(@"sharedManager");
    id sharedManager = ((id (*)(id, SEL))[advertisingManager methodForSelector:sharedManagerSelector])(advertisingManager, sharedManagerSelector);
    SEL adTrackingEnabledSEL = NSSelectorFromString(@"isAdvertisingTrackingEnabled");
    result = ((BOOL (*)(id, SEL))[sharedManager methodForSelector:adTrackingEnabledSEL])(sharedManager, adTrackingEnabledSEL);
    return result;
}


@interface ByteGainSegmentIntegration ()

@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, strong) NSDictionary *cachedStaticContext;
@property (nonatomic, strong) NSURLSessionUploadTask *batchRequest;
@property (nonatomic, assign) UIBackgroundTaskIdentifier flushTaskID;
@property (nonatomic, strong) ByteGainReachability *reachability;
@property (nonatomic, strong) NSTimer *flushTimer;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) dispatch_queue_t backgroundTaskQueue;
@property (nonatomic, strong) NSMutableDictionary *traits;
@property (nonatomic, assign) ByteGainAnalytics *analytics;
@property (nonatomic, assign) ByteGainAnalyticsConfiguration *configuration;
@property (atomic, copy) NSDictionary *referrer;
@property (nonatomic, copy) NSString *userId;
//@property (nonatomic, strong) NSURL *apiURL;
@property (nonatomic, strong) ByteGainHTTPClient *httpClient;
@property (nonatomic, strong) id<ByteGainStorage> storage;
@property (nonatomic, strong) NSURLSessionDataTask *attributionRequest;
@property (nonatomic, strong) NSMutableDictionary *responsePayloads;  // accessed only by main thread.  Maps response call ID to ByteGainPayload (has callbacks)
@property (nonatomic, assign) long long nextResponseId;  // accessed only by main thread.  generates keys for calls with responses
@property (nonatomic, strong) NSMutableDictionary *goalNameToTrackProperties;  // accessed only by background thread

@end

@implementation ByteGainSegmentIntegration

- (id)initWithAnalytics:(ByteGainAnalytics *)analytics httpClient:(ByteGainHTTPClient *)httpClient storage:(id<ByteGainStorage>)storage
{
    if (self = [super init]) {
        self.analytics = analytics;
        self.configuration = analytics.configuration;
        self.httpClient = httpClient;
        self.storage = storage;
//        self.apiURL = [BYTEGAIN_API_BASE URLByAppendingPathComponent:@"import"];
        self.userId = [self getUserId];
        self.reachability = [ByteGainReachability reachabilityWithHostname:@"google.com"];
        [self.reachability startNotifier];
        self.cachedStaticContext = [self staticContext];
        self.serialQueue = seg_dispatch_queue_create_specific("io.segment.analytics.segmentio", DISPATCH_QUEUE_SERIAL);
        self.backgroundTaskQueue = seg_dispatch_queue_create_specific("io.segment.analytics.backgroundTask", DISPATCH_QUEUE_SERIAL);
        self.flushTaskID = UIBackgroundTaskInvalid;
        self.responsePayloads = [NSMutableDictionary dictionary];
        self.nextResponseId = 1;
        self.goalNameToTrackProperties = [[NSMutableDictionary alloc] init];

#if !TARGET_OS_TV
        // Check for previous queue/track data in NSUserDefaults and remove if present
        [self dispatchBackground:^{
            if ([[NSUserDefaults standardUserDefaults] objectForKey:ByteGainQueueKey]) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:ByteGainQueueKey];
            }
            if ([[NSUserDefaults standardUserDefaults] objectForKey:ByteGainTraitsKey]) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:ByteGainTraitsKey];
            }
        }];
#endif
        [self dispatchBackground:^{
            [self trackAttributionData:self.configuration.trackAttributionData];
        }];

        if ([NSThread isMainThread]) {
            [self setupFlushTimer];
        } else {
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self setupFlushTimer];
            });
        }
    }
    return self;
}

- (void)setupFlushTimer
{
    self.flushTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 target:self selector:@selector(flush) userInfo:nil repeats:YES];
}

/*
 * There is an iOS bug that causes instances of the CTTelephonyNetworkInfo class to
 * sometimes get notifications after they have been deallocated.
 * Instead of instantiating, using, and releasing instances you * must instead retain
 * and never release them to work around the bug.
 *
 * Ref: http://stackoverflow.com/questions/14238586/coretelephony-crash
 */

#if TARGET_OS_IOS
static CTTelephonyNetworkInfo *_telephonyNetworkInfo;
#endif

- (NSDictionary *)staticContext
{
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];

    dict[@"library"] = @{
        @"name" : @"analytics-ios",
        @"version" : [ByteGainAnalytics version]
    };

    NSMutableDictionary *infoDictionary = [[[NSBundle mainBundle] infoDictionary] mutableCopy];
    [infoDictionary addEntriesFromDictionary:[[NSBundle mainBundle] localizedInfoDictionary]];
    if (infoDictionary.count) {
        dict[@"app"] = @{
            @"name" : infoDictionary[@"CFBundleDisplayName"] ?: @"",
            @"version" : infoDictionary[@"CFBundleShortVersionString"] ?: @"",
            @"build" : infoDictionary[@"CFBundleVersion"] ?: @"",
            @"namespace" : [[NSBundle mainBundle] bundleIdentifier] ?: @"",
        };
    }

    UIDevice *device = [UIDevice currentDevice];

    dict[@"device"] = ({
        NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
        dict[@"manufacturer"] = @"Apple";
        dict[@"model"] = GetDeviceModel();
        dict[@"id"] = [[device identifierForVendor] UUIDString];
        if (NSClassFromString(ByteGainAdvertisingClassIdentifier)) {
            dict[@"adTrackingEnabled"] = @(GetAdTrackingEnabled());
        }
        if (self.configuration.enableAdvertisingTracking) {
            NSString *idfa = ByteGainIDFA();
            if (idfa.length) dict[@"advertisingId"] = idfa;
        }
        dict;
    });

    dict[@"os"] = @{
        @"name" : device.systemName,
        @"version" : device.systemVersion
    };

    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    dict[@"screen"] = @{
        @"width" : @(screenSize.width),
        @"height" : @(screenSize.height)
    };

#if !(TARGET_IPHONE_SIMULATOR)
    Class adClient = NSClassFromString(ByteGainADClientClass);
    if (adClient) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id sharedClient = [adClient performSelector:NSSelectorFromString(@"sharedClient")];
#pragma clang diagnostic pop
        void (^completionHandler)(BOOL iad) = ^(BOOL iad) {
            if (iad) {
                dict[@"referrer"] = @{ @"type" : @"iad" };
            }
        };
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [sharedClient performSelector:NSSelectorFromString(@"determineAppInstallationAttributionWithCompletionHandler:")
                           withObject:completionHandler];
#pragma clang diagnostic pop
    }
#endif

    return dict;
}

- (NSDictionary *)liveContext
{
    NSMutableDictionary *context = [[NSMutableDictionary alloc] init];
    context[@"locale"] = [NSString stringWithFormat:
                                       @"%@-%@",
                                       [NSLocale.currentLocale objectForKey:NSLocaleLanguageCode],
                                       [NSLocale.currentLocale objectForKey:NSLocaleCountryCode]];

    context[@"timezone"] = [[NSTimeZone localTimeZone] name];

    context[@"network"] = ({
        NSMutableDictionary *network = [[NSMutableDictionary alloc] init];

        if (self.reachability.isReachable) {
            network[@"wifi"] = @(self.reachability.isReachableViaWiFi);
            network[@"cellular"] = @(self.reachability.isReachableViaWWAN);
        }

#if TARGET_OS_IOS
        static dispatch_once_t networkInfoOnceToken;
        dispatch_once(&networkInfoOnceToken, ^{
            _telephonyNetworkInfo = [[CTTelephonyNetworkInfo alloc] init];
        });

        CTCarrier *carrier = [_telephonyNetworkInfo subscriberCellularProvider];
        if (carrier.carrierName.length)
            network[@"carrier"] = carrier.carrierName;
#endif

        network;
    });

    context[@"traits"] = ({
        NSMutableDictionary *traits = [[NSMutableDictionary alloc] initWithDictionary:[self traits]];
        traits;
    });

    if (self.referrer) {
        context[@"referrer"] = [self.referrer copy];
    }

    return [context copy];
}

- (void)dispatchBackground:(void (^)(void))block
{
    seg_dispatch_specific_async(_serialQueue, block);
}

- (void)dispatchBackgroundAndWait:(void (^)(void))block
{
    seg_dispatch_specific_sync(_serialQueue, block);
}

- (void)beginBackgroundTask
{
    [self endBackgroundTask];

    seg_dispatch_specific_sync(_backgroundTaskQueue, ^{
        id<ByteGainApplicationProtocol> application = [self.analytics configuration].application;
        if (application) {
            self.flushTaskID = [application seg_beginBackgroundTaskWithName:@"Segmentio.Flush"
                                                          expirationHandler:^{
                                                              [self endBackgroundTask];
                                                          }];
        }
    });
}

- (void)endBackgroundTask
{
    // endBackgroundTask and beginBackgroundTask can be called from main thread
    // We should not dispatch to the same queue we use to flush events because it can cause deadlock
    // inside @synchronized(self) block for ByteGainIntegrationsManager as both events queue and main queue
    // attempt to call forwardSelector:arguments:options:
    // See https://github.com/segmentio/analytics-ios/issues/683
    seg_dispatch_specific_sync(_backgroundTaskQueue, ^{
        if (self.flushTaskID != UIBackgroundTaskInvalid) {
            id<ByteGainApplicationProtocol> application = [self.analytics configuration].application;
            if (application) {
                [application seg_endBackgroundTask:self.flushTaskID];
            }

            self.flushTaskID = UIBackgroundTaskInvalid;
        }
    });
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, self.class, self.configuration.writeKey];
}

- (void)saveUserId:(NSString *)userId
{
    [self dispatchBackground:^{
        self.userId = userId;

#if TARGET_OS_TV
        [self.storage setString:userId forKey:ByteGainUserIdKey];
#else
        [self.storage setString:userId forKey:kByteGainUserIdFilename];
#endif
    }];
}

- (void)addTraits:(NSDictionary *)traits
{
    [self dispatchBackground:^{
        [self.traits addEntriesFromDictionary:traits];

#if TARGET_OS_TV
        [self.storage setDictionary:[self.traits copy] forKey:ByteGainTraitsKey];
#else
        [self.storage setDictionary:[self.traits copy] forKey:kByteGainTraitsFilename];
#endif
    }];
}

#pragma mark - Analytics API

- (void)identify:(ByteGainIdentifyPayload *)payload
{
    [self dispatchBackground:^{
        [self saveUserId:payload.userId];
        [self addTraits:payload.traits];
    }];

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.traits forKey:@"traits"];

    [self enqueueAction:@"identify" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)track:(ByteGainTrackPayload *)payload
{
    ByteGainLog(@"segment integration received payload %@", payload);

    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.event forKey:@"event"];
    [dictionary setValue:payload.properties forKey:@"properties"];
    [self enqueueAction:@"track" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)screen:(ByteGainScreenPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.name forKey:@"name"];
    [dictionary setValue:payload.properties forKey:@"properties"];

    [self enqueueAction:@"screen" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)attemptGoal:(ByteGainAttemptGoalPayload *)payload
{
    NSString *key = [NSString stringWithFormat:@"r%lld", self.nextResponseId];
    self.nextResponseId += 1;
    [self.responsePayloads setObject:payload forKey:key];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.event forKey:@"intervention"];
    [dictionary setValue:payload.properties forKey:@"properties"];
    [dictionary setValue:key forKey:kResponseIdKey];
    [self enqueueAction:@"intervention" dictionary:dictionary context:payload.context integrations:payload.integrations];
    [self flush];  // get a response promptly
}

- (void)reportGoalResult:(ByteGainReportGoalResultPayload *)payload
{
    NSString *result = payload.result == ByteGainGoalResultFailure ? @"failure" : @"success";
    NSDictionary *trackProperties = [[NSMutableDictionary alloc]
                                     initWithObjectsAndKeys:@"result", @"intervention",
                                     result, @"result", nil];
    NSDictionary *attemptProperties = [self.goalNameToTrackProperties objectForKey:payload.event];
    if (attemptProperties) {
        if (payload.result != ByteGainGoalResultUnsolictedSuccess) {
            [trackProperties setValue:[attemptProperties objectForKey:@"attemptId"] forKey:@"attemptId"];
            if ([attemptProperties objectForKey:@"variant"]) {
                [trackProperties setValue:[attemptProperties objectForKey:@"variant"] forKey:@"variant"];
            }
        }
        [self.goalNameToTrackProperties removeObjectForKey:payload.event];
    }
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] initWithObjectsAndKeys:payload.event, @"event",
                                       trackProperties, @"properties", nil];
    [self enqueueAction:@"track" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)group:(ByteGainGroupPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.groupId forKey:@"groupId"];
    [dictionary setValue:payload.traits forKey:@"traits"];

    [self enqueueAction:@"group" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)alias:(ByteGainAliasPayload *)payload
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    [dictionary setValue:payload.theNewId forKey:@"userId"];
    [dictionary setValue:self.userId ?: [self.analytics getAnonymousId] forKey:@"previousId"];

    [self enqueueAction:@"alias" dictionary:dictionary context:payload.context integrations:payload.integrations];
}

- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSCParameterAssert(deviceToken != nil);

    const unsigned char *buffer = (const unsigned char *)[deviceToken bytes];
    if (!buffer) {
        return;
    }
    NSMutableString *token = [NSMutableString stringWithCapacity:(deviceToken.length * 2)];
    for (NSUInteger i = 0; i < deviceToken.length; i++) {
        [token appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)buffer[i]]];
    }
    [self.cachedStaticContext[@"device"] setObject:[token copy] forKey:@"token"];
}

- (void)continueUserActivity:(NSUserActivity *)activity
{
    if ([activity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        self.referrer = @{
            @"url" : activity.webpageURL.absoluteString,
        };
    }
}

- (void)openURL:(NSURL *)url options:(NSDictionary *)options
{
    self.referrer = @{
        @"url" : url.absoluteString,
    };
}

#pragma mark - Queueing

// Merges user provided integration options with bundled integrations.
- (NSDictionary *)integrationsDictionary:(NSDictionary *)integrations
{
    NSMutableDictionary *dict = [integrations ?: @{} mutableCopy];
    for (NSString *integration in self.analytics.bundledIntegrations) {
        // Don't record Segment.io in the dictionary. It is always enabled.
        if ([integration isEqualToString:@"Segment.io"]) {
            continue;
        }
        dict[integration] = @NO;
    }
    return [dict copy];
}

- (void)enqueueAction:(NSString *)action dictionary:(NSMutableDictionary *)payload context:(NSDictionary *)context integrations:(NSDictionary *)integrations
{
    // attach these parts of the payload outside since they are all synchronous
    // and the timestamp will be more accurate.
    payload[@"type"] = action;
    payload[@"timestamp"] = iso8601FormattedString([NSDate date]);
    payload[@"messageId"] = GenerateUUIDString();

    [self dispatchBackground:^{
        // attach userId and anonymousId inside the dispatch_async in case
        // they've changed (see identify function)

        // Do not override the userId for an 'alias' action. This value is set in [alias:] already.
        if (![action isEqualToString:@"alias"]) {
            [payload setValue:self.userId forKey:@"userId"];
        }
        [payload setValue:[self.analytics getAnonymousId] forKey:@"anonymousId"];

        [payload setValue:[self integrationsDictionary:integrations] forKey:@"integrations"];

        NSDictionary *staticContext = self.cachedStaticContext;
        NSDictionary *liveContext = [self liveContext];
        NSDictionary *customContext = context;
        NSMutableDictionary *context = [NSMutableDictionary dictionaryWithCapacity:staticContext.count + liveContext.count + customContext.count];
        [context addEntriesFromDictionary:staticContext];
        [context addEntriesFromDictionary:liveContext];
        [context addEntriesFromDictionary:customContext];
        [payload setValue:[context copy] forKey:@"context"];

        ByteGainLog(@"%@ Enqueueing action: %@", self, payload);
        [self queuePayload:[payload copy]];
    }];
}

- (void)queuePayload:(NSDictionary *)payload
{
    @try {
        // We only queue upto 1000 items, so trim the queue to 1000-1=999
        // before we add a new element.
        trimQueue(self.queue, 999);
        [self.queue addObject:payload];
        [self persistQueue];
        [self flushQueueByLength];
    }
    @catch (NSException *exception) {
        ByteGainLog(@"%@ Error writing payload: %@", self, exception);
    }
}

- (void)flush
{
    [self flushWithMaxSize:self.maxBatchSize];
}

- (void)flushWithMaxSize:(NSUInteger)maxBatchSize
{
    [self dispatchBackground:^{
        if ([self.queue count] == 0) {
            ByteGainLog(@"%@ No queued API calls to flush.", self);
            [self endBackgroundTask];
            return;
        }
        if (self.batchRequest != nil) {
            ByteGainLog(@"%@ API request already in progress, not flushing again.", self);
            return;
        }

        NSArray *batch;
        if ([self.queue count] >= maxBatchSize) {
            batch = [self.queue subarrayWithRange:NSMakeRange(0, maxBatchSize)];
        } else {
            batch = [NSArray arrayWithArray:self.queue];
        }

        [self sendData:batch];
    }];
}

- (void)flushQueueByLength
{
    [self dispatchBackground:^{
        ByteGainLog(@"%@ Length is %lu.", self, (unsigned long)self.queue.count);

        if (self.batchRequest == nil && [self.queue count] >= self.configuration.flushAt) {
            [self flush];
        }
    }];
}

- (void)reset
{
    [self dispatchBackgroundAndWait:^{
#if TARGET_OS_TV
        [self.storage removeKey:ByteGainUserIdKey];
        [self.storage removeKey:ByteGainTraitsKey];
#else
        [self.storage removeKey:kByteGainUserIdFilename];
        [self.storage removeKey:kByteGainTraitsFilename];
#endif

        self.userId = nil;
        self.traits = [NSMutableDictionary dictionary];
    }];
}

- (void)notifyForName:(NSString *)name userInfo:(id)userInfo
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:name object:userInfo];
        ByteGainLog(@"sent notification %@", name);
    });
}

- (void)sendData:(NSArray *)batch
{
    NSMutableDictionary *payload = [[NSMutableDictionary alloc] init];
    [payload setObject:iso8601FormattedString([NSDate date]) forKey:@"sentAt"];
    [payload setObject:batch forKey:@"batch"];

    ByteGainLog(@"%@ Flushing %lu of %lu queued API calls.", self, (unsigned long)batch.count, (unsigned long)self.queue.count);
    ByteGainLog(@"Flushing batch %@.", payload);

    self.batchRequest = [self.httpClient upload:payload forWriteKey:self.configuration.writeKey
                              completionHandler:^(BOOL retry, JSON_DICT _Nullable data) {
        [self dispatchBackground:^{
            if (retry) {
                [self notifyForName:ByteGainSegmentRequestDidFailNotification userInfo:batch];
                self.batchRequest = nil;
                [self endBackgroundTask];
                return;
            }
            [self deliverResponses:batch data:data];
            [self.queue removeObjectsInArray:batch];
            [self persistQueue];
            [self notifyForName:ByteGainSegmentRequestDidSucceedNotification userInfo:batch];
            self.batchRequest = nil;
            [self endBackgroundTask];
        }];
    }];

    [self notifyForName:ByteGainSegmentDidSendRequestNotification userInfo:batch];
}

- (void)deliverResponses:(NSArray *)batch data:(JSON_DICT _Nullable)data
{
    // Parse the responses
    NSDictionary *jsonResponse = nil;
    if (data != nil) {
        jsonResponse = [data objectForKey:@"responses"];
    }

    // Deliver a response to each payload in batch that is expecting one.
    for (NSDictionary *payload in batch) {
        NSString *key = [payload objectForKey:kResponseIdKey];
        if (key == nil) {
            continue;
        }
        ByteGainAttemptGoalPayload *attemptPayload = [ByteGainAttemptGoalPayload cast:[self.responsePayloads objectForKey:key]];
        if (attemptPayload == nil) {
            ByteGainLog(@"no attempt payload");
            continue;
        }
        if (attemptPayload.event == nil) {
            ByteGainLog(@"attemptPayload.event is nil");
            continue;
        }
        NSDictionary *responseData = [jsonResponse objectForKey:key];
        if (responseData != nil && [[responseData objectForKey:@"intervene"] boolValue]) {
            dispatch_block_t finish = ^{
                NSString *attempt_id = [responseData valueForKey:@"attemptId"];
                NSObject *delay_secs = [responseData valueForKey:@"delaySecs"];
                NSString *variant = [responseData objectForKey:@"variant"];
                NSMutableDictionary *trackProperties =
                    [[NSMutableDictionary alloc] init];
                [trackProperties setObject:@"attempt" forKey:@"intervention"];
                if (attempt_id != nil) {
                    [trackProperties setObject:attempt_id forKey:@"attemptId"];
                }
                if (delay_secs != nil) {
                    [trackProperties setObject:delay_secs forKey:@"delaySecs"];
                }
                if (variant != nil) {
                    [trackProperties setObject:variant forKey:@"variant"];
                }
                // Must be run on serialQueue's thread.  Store attemptId shortly before invoking yesCallback().
                [self.goalNameToTrackProperties setValue:trackProperties forKey:attemptPayload.event];  // used by reportGoalResult
                dispatch_async(dispatch_get_main_queue(), ^{
                    // We follow the pattern of [self dispatchBackground...], whose implementation puts an
                    // @autoreleasepool before calling the block.
                    @autoreleasepool
                    {
                        [[ByteGainAnalytics sharedAnalytics] track:attemptPayload.event properties:trackProperties];
                        attemptPayload.yesCallback(variant);
                    }
                });
            };
            float delaySecs = 0.;
            if ([[responseData valueForKey:@"delaySecs"] isKindOfClass:[NSNumber class]]) {
                delaySecs = [[responseData valueForKey:@"delaySecs"] floatValue];
            }
            if (delaySecs > 0) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delaySecs * NSEC_PER_SEC)),
                               _serialQueue, ^{
                                   @autoreleasepool
                                   {
                                       finish();
                                   }
                               });
            } else {
                finish();
            }
        } else if (attemptPayload.noCallback != nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                @autoreleasepool
                {
                    attemptPayload.noCallback();
                }
            });
        }
        
        // Clean up responsePayloads
        [self.responsePayloads removeObjectForKey:key];
    }
}

- (void)applicationDidEnterBackground
{
    [self beginBackgroundTask];
    // We are gonna try to flush as much as we reasonably can when we enter background
    // since there is a chance that the user will never launch the app again.
    [self flush];
}

- (void)applicationWillTerminate
{
    [self dispatchBackgroundAndWait:^{
        if (self.queue.count)
            [self persistQueue];
    }];
}

#pragma mark - Private

- (NSMutableArray *)queue
{
    if (!_queue) {
#if TARGET_OS_TV
        _queue = [[self.storage arrayForKey:ByteGainQueueKey] ?: @[] mutableCopy];
#else
        _queue = [[self.storage arrayForKey:kByteGainQueueFilename] ?: @[] mutableCopy];
#endif
    }

    return _queue;
}

- (NSMutableDictionary *)traits
{
    if (!_traits) {
#if TARGET_OS_TV
        _traits = [[self.storage dictionaryForKey:ByteGainTraitsKey] ?: @{} mutableCopy];
#else
        _traits = [[self.storage dictionaryForKey:kByteGainTraitsFilename] ?: @{} mutableCopy];
#endif
    }

    return _traits;
}

- (NSUInteger)maxBatchSize
{
    return 100;
}

- (NSString *)getUserId
{
    return [[NSUserDefaults standardUserDefaults] valueForKey:ByteGainUserIdKey] ?: [self.storage stringForKey:kByteGainUserIdFilename];
}

- (void)persistQueue
{
#if TARGET_OS_TV
    [self.storage setArray:[self.queue copy] forKey:ByteGainQueueKey];
#else
    [self.storage setArray:[self.queue copy] forKey:kByteGainQueueFilename];
#endif
}

NSString *const ByteGainTrackedAttributionKey = @"ByteGainTrackedAttributionKey";

- (void)trackAttributionData:(BOOL)trackAttributionData
{
    // ByteGain does not support this
    /*
#if TARGET_OS_IPHONE
    if (!trackAttributionData) {
        return;
    }

    BOOL trackedAttribution = [[NSUserDefaults standardUserDefaults] boolForKey:ByteGainTrackedAttributionKey];
    if (trackedAttribution) {
        return;
    }

    NSDictionary *staticContext = self.cachedStaticContext;
    NSDictionary *liveContext = [self liveContext];
    NSMutableDictionary *context = [NSMutableDictionary dictionaryWithCapacity:staticContext.count + liveContext.count];
    [context addEntriesFromDictionary:staticContext];
    [context addEntriesFromDictionary:liveContext];

    self.attributionRequest = [self.httpClient attributionWithWriteKey:self.configuration.writeKey forDevice:[context copy] completionHandler:^(BOOL success, NSDictionary *properties) {
        [self dispatchBackground:^{
            if (success) {
                [self.analytics track:@"Install Attributed" properties:properties];
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:ByteGainTrackedAttributionKey];
            }
            self.attributionRequest = nil;
        }];
    }];
#endif
     */
}

@end
