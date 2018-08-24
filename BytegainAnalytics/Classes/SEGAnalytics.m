#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import "SEGAnalyticsUtils.h"
#import "SEGAnalytics.h"
#import "SEGIntegrationFactory.h"
#import "SEGIntegration.h"
#import "SEGSegmentIntegrationFactory.h"
#import "UIViewController+SEGScreen.h"
#import "SEGStoreKitTracker.h"
#import "SEGHTTPClient.h"
#import "SEGStorage.h"
#import "SEGFileStorage.h"
#import "SEGUserDefaultsStorage.h"
#import "SEGMiddleware.h"
#import "SEGContext.h"
#import "SEGIntegrationsManager.h"

static ByteGainAnalytics *__sharedInstance = nil;


@interface ByteGainAnalytics ()

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) ByteGainAnalyticsConfiguration *configuration;
@property (nonatomic, strong) ByteGainStoreKitTracker *storeKitTracker;
@property (nonatomic, strong) ByteGainIntegrationsManager *integrationsManager;
@property (nonatomic, strong) ByteGainMiddlewareRunner *runner;

@end


@implementation ByteGainAnalytics

+ (void)setupWithConfiguration:(ByteGainAnalyticsConfiguration *)configuration
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __sharedInstance = [[self alloc] initWithConfiguration:configuration];
    });
}

- (instancetype)initWithConfiguration:(ByteGainAnalyticsConfiguration *)configuration
{
    NSCParameterAssert(configuration != nil);

    if (self = [self init]) {
        self.configuration = configuration;
        self.enabled = YES;

        // In swift this would not have been OK... But hey.. It's objc
        // TODO: Figure out if this is really the best way to do things here.
        self.integrationsManager = [[ByteGainIntegrationsManager alloc] initWithAnalytics:self];

        self.runner = [[ByteGainMiddlewareRunner alloc] initWithMiddlewares:
                                                       [configuration.middlewares ?: @[] arrayByAddingObject:self.integrationsManager]];

        // Attach to application state change hooks
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

        // Pass through for application state change events
        id<ByteGainApplicationProtocol> application = configuration.application;
        if (application) {
            for (NSString *name in @[ UIApplicationDidEnterBackgroundNotification,
                                      UIApplicationDidFinishLaunchingNotification,
                                      UIApplicationWillEnterForegroundNotification,
                                      UIApplicationWillTerminateNotification,
                                      UIApplicationWillResignActiveNotification,
                                      UIApplicationDidBecomeActiveNotification ]) {
                [nc addObserver:self selector:@selector(handleAppStateNotification:) name:name object:application];
            }
        }

        if (configuration.recordScreenViews) {
            [UIViewController seg_swizzleViewDidAppear];
        }
        if (configuration.trackInAppPurchases) {
            _storeKitTracker = [ByteGainStoreKitTracker trackTransactionsForAnalytics:self];
        }

#if !TARGET_OS_TV
        if (configuration.trackPushNotifications && configuration.launchOptions) {
            NSDictionary *remoteNotification = configuration.launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
            if (remoteNotification) {
                [self trackPushNotification:remoteNotification fromLaunch:YES];
            }
        }
#endif
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -

NSString *const ByteGainVersionKey = @"ByteGainVersionKey";
NSString *const ByteGainBuildKeyV1 = @"ByteGainBuildKey";
NSString *const ByteGainBuildKeyV2 = @"ByteGainBuildKeyV2";

- (void)handleAppStateNotification:(NSNotification *)note
{
    ByteGainApplicationLifecyclePayload *payload = [[ByteGainApplicationLifecyclePayload alloc] init];
    payload.notificationName = note.name;
    [self run:ByteGainEventTypeApplicationLifecycle payload:payload];

    if ([note.name isEqualToString:UIApplicationDidFinishLaunchingNotification]) {
        [self _applicationDidFinishLaunchingWithOptions:note.userInfo];
    } else if ([note.name isEqualToString:UIApplicationWillEnterForegroundNotification]) {
        [self _applicationWillEnterForeground];
    }
}

- (void)_applicationDidFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    if (!self.configuration.trackApplicationLifecycleEvents) {
        return;
    }
    // Previously ByteGainBuildKey was stored an integer. This was incorrect because the CFBundleVersion
    // can be a string. This migrates ByteGainBuildKey to be stored as a string.
    NSInteger previousBuildV1 = [[NSUserDefaults standardUserDefaults] integerForKey:ByteGainBuildKeyV1];
    if (previousBuildV1) {
        [[NSUserDefaults standardUserDefaults] setObject:[@(previousBuildV1) stringValue] forKey:ByteGainBuildKeyV2];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:ByteGainBuildKeyV1];
    }

    NSString *previousVersion = [[NSUserDefaults standardUserDefaults] stringForKey:ByteGainVersionKey];
    NSString *previousBuildV2 = [[NSUserDefaults standardUserDefaults] stringForKey:ByteGainBuildKeyV2];

    NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    NSString *currentBuild = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];

    if (!previousBuildV2) {
        [self track:@"Application Installed" properties:@{
            @"version" : currentVersion ?: @"",
            @"build" : currentBuild ?: @"",
        }];
    } else if (![currentBuild isEqualToString:previousBuildV2]) {
        [self track:@"Application Updated" properties:@{
            @"previous_version" : previousVersion ?: @"",
            @"previous_build" : previousBuildV2 ?: @"",
            @"version" : currentVersion ?: @"",
            @"build" : currentBuild ?: @"",
        }];
    }

    [self track:@"Application Opened" properties:@{
        @"from_background" : @NO,
        @"version" : currentVersion ?: @"",
        @"build" : currentBuild ?: @"",
        @"referring_application" : launchOptions[UIApplicationLaunchOptionsSourceApplicationKey] ?: @"",
        @"url" : launchOptions[UIApplicationLaunchOptionsURLKey] ?: @"",
    }];


    [[NSUserDefaults standardUserDefaults] setObject:currentVersion forKey:ByteGainVersionKey];
    [[NSUserDefaults standardUserDefaults] setObject:currentBuild forKey:ByteGainBuildKeyV2];

    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)_applicationWillEnterForeground
{
    if (!self.configuration.trackApplicationLifecycleEvents) {
        return;
    }
    NSString *currentVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    NSString *currentBuild = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
    [self track:@"Application Opened" properties:@{
        @"from_background" : @YES,
        @"version" : currentVersion ?: @"",
        @"build" : currentBuild ?: @"",
    }];
}


#pragma mark - Public API

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%p:%@, %@>", self, [self class], [self dictionaryWithValuesForKeys:@[ @"configuration" ]]];
}

#pragma mark - Identify

- (void)identify:(NSString *)userId
{
    [self identify:userId traits:nil options:nil];
}

- (void)identify:(NSString *)userId traits:(NSDictionary *)traits
{
    [self identify:userId traits:traits options:nil];
}

- (void)identify:(NSString *)userId traits:(NSDictionary *)traits options:(NSDictionary *)options
{
    NSCAssert2(userId.length > 0 || traits.count > 0, @"either userId (%@) or traits (%@) must be provided.", userId, traits);
    [self run:ByteGainEventTypeIdentify payload:
                                       [[ByteGainIdentifyPayload alloc] initWithUserId:userId
                                                                      anonymousId:nil
                                                                           traits:ByteGainCoerceDictionary(traits)
                                                                          context:ByteGainCoerceDictionary([options objectForKey:@"context"])
                                                                     integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - Track

- (void)track:(NSString *)event
{
    [self track:event properties:nil options:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties
{
    [self track:event properties:properties options:nil];
}

- (void)track:(NSString *)event properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    NSCAssert1(event.length > 0, @"event (%@) must not be empty.", event);
    [self run:ByteGainEventTypeTrack payload:
                                    [[ByteGainTrackPayload alloc] initWithEvent:event
                                                                properties:ByteGainCoerceDictionary(properties)
                                                                   context:ByteGainCoerceDictionary([options objectForKey:@"context"])
                                                              integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - Screen

- (void)screen:(NSString *)screenTitle
{
    [self screen:screenTitle properties:nil options:nil];
}

- (void)screen:(NSString *)screenTitle properties:(NSDictionary *)properties
{
    [self screen:screenTitle properties:properties options:nil];
}

- (void)screen:(NSString *)screenTitle properties:(NSDictionary *)properties options:(NSDictionary *)options
{
    NSCAssert1(screenTitle.length > 0, @"screen name (%@) must not be empty.", screenTitle);

    [self run:ByteGainEventTypeScreen payload:
                                     [[ByteGainScreenPayload alloc] initWithName:screenTitle
                                                                 properties:ByteGainCoerceDictionary(properties)
                                                                    context:ByteGainCoerceDictionary([options objectForKey:@"context"])
                                                               integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - AttemptGoal

- (void)    attemptGoal:(NSString *)goalName
    makeAttemptCallback:(nonnull ByteGainGoalMakeAttemptCallback)makeAttemptCallback
dontMakeAttemptCallback:(nonnull ByteGainGoalDontMakeAttemptCallback)dontMakeAttemptCallback
                options:(NSDictionary * _Nullable)options
{
    [self run:ByteGainEventTypeAttemptGoal payload:
                                      [[ByteGainAttemptGoalPayload alloc] initWithEvent:goalName
                                                                        properties:@{}
                                                                           context:ByteGainCoerceDictionary([options objectForKey:@"context"])
                                                                      integrations:[options objectForKey:@"integrations"]
                                                                   yesCallback:[makeAttemptCallback copy]
                                                                   noCallback:[dontMakeAttemptCallback copy]]];
}

- (void)    attemptGoal:(NSString *)goalName
    makeAttemptCallback:(ByteGainGoalMakeAttemptCallback)makeAttemptCallback
dontMakeAttemptCallback:(ByteGainGoalDontMakeAttemptCallback)dontMakeAttemptCallback
{
    [self attemptGoal:goalName makeAttemptCallback:makeAttemptCallback dontMakeAttemptCallback:dontMakeAttemptCallback options:nil];
}

- (void)    attemptGoal:(NSString *)goalName makeAttemptCallback:(ByteGainGoalMakeAttemptCallback)makeAttemptCallback
{
    [self attemptGoal:goalName makeAttemptCallback:makeAttemptCallback dontMakeAttemptCallback:^{} options:nil];
}

#pragma mark - ReportGoalResult

- (void)reportGoalResult:(NSString*)goalName result:(ByteGainGoalResult)result options:(NSDictionary *)options
{
    [self run:ByteGainEventTypeReportGoalResult payload:[[ByteGainReportGoalResultPayload alloc] initWithEvent:goalName
                                                                                              result:result
                                                                                             context:ByteGainCoerceDictionary(ByteGainCoerceDictionary([options objectForKey:@"context"]))
                                                                                        integrations:[options objectForKey:@"integrations"]]];
}

- (void)reportGoalResult:(NSString*)goalName result:(ByteGainGoalResult)result
{
    [self reportGoalResult:goalName result:result options:nil];
}

#pragma mark - Group

- (void)group:(NSString *)groupId
{
    [self group:groupId traits:nil options:nil];
}

- (void)group:(NSString *)groupId traits:(NSDictionary *)traits
{
    [self group:groupId traits:traits options:nil];
}

- (void)group:(NSString *)groupId traits:(NSDictionary *)traits options:(NSDictionary *)options
{
    [self run:ByteGainEventTypeGroup payload:
                                    [[ByteGainGroupPayload alloc] initWithGroupId:groupId
                                                                      traits:ByteGainCoerceDictionary(traits)
                                                                     context:ByteGainCoerceDictionary([options objectForKey:@"context"])
                                                                integrations:[options objectForKey:@"integrations"]]];
}

#pragma mark - Alias

- (void)alias:(NSString *)newId
{
    [self alias:newId options:nil];
}

- (void)alias:(NSString *)newId options:(NSDictionary *)options
{
    [self run:ByteGainEventTypeAlias payload:
                                    [[ByteGainAliasPayload alloc] initWithNewId:newId
                                                                   context:ByteGainCoerceDictionary([options objectForKey:@"context"])
                                                              integrations:[options objectForKey:@"integrations"]]];
}

- (void)trackPushNotification:(NSDictionary *)properties fromLaunch:(BOOL)launch
{
    if (launch) {
        [self track:@"Push Notification Tapped" properties:properties];
    } else {
        [self track:@"Push Notification Received" properties:properties];
    }
}

- (void)receivedRemoteNotification:(NSDictionary *)userInfo
{
    if (self.configuration.trackPushNotifications) {
        [self trackPushNotification:userInfo fromLaunch:NO];
    }
    ByteGainRemoteNotificationPayload *payload = [[ByteGainRemoteNotificationPayload alloc] init];
    payload.userInfo = userInfo;
    [self run:ByteGainEventTypeReceivedRemoteNotification payload:payload];
}

- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    ByteGainRemoteNotificationPayload *payload = [[ByteGainRemoteNotificationPayload alloc] init];
    payload.error = error;
    [self run:ByteGainEventTypeFailedToRegisterForRemoteNotifications payload:payload];
}

- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSParameterAssert(deviceToken != nil);
    ByteGainRemoteNotificationPayload *payload = [[ByteGainRemoteNotificationPayload alloc] init];
    payload.deviceToken = deviceToken;
    [self run:ByteGainEventTypeRegisteredForRemoteNotifications payload:payload];
}

- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo
{
    ByteGainRemoteNotificationPayload *payload = [[ByteGainRemoteNotificationPayload alloc] init];
    payload.actionIdentifier = identifier;
    payload.userInfo = userInfo;
    [self run:ByteGainEventTypeHandleActionWithForRemoteNotification payload:payload];
}

- (void)continueUserActivity:(NSUserActivity *)activity
{
    ByteGainContinueUserActivityPayload *payload = [[ByteGainContinueUserActivityPayload alloc] init];
    payload.activity = activity;
    [self run:ByteGainEventTypeContinueUserActivity payload:payload];

    if (!self.configuration.trackDeepLinks) {
        return;
    }

    if ([activity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
        NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithCapacity:activity.userInfo.count + 2];
        [properties addEntriesFromDictionary:activity.userInfo];
        properties[@"url"] = activity.webpageURL.absoluteString;
        properties[@"title"] = activity.title ?: @"";
        [self track:@"Deep Link Opened" properties:[properties copy]];
    }
}

- (void)openURL:(NSURL *)url options:(NSDictionary *)options
{
    ByteGainOpenURLPayload *payload = [[ByteGainOpenURLPayload alloc] init];
    payload.url = url;
    payload.options = options;
    [self run:ByteGainEventTypeOpenURL payload:payload];

    if (!self.configuration.trackDeepLinks) {
        return;
    }

    NSMutableDictionary *properties = [NSMutableDictionary dictionaryWithCapacity:options.count + 2];
    [properties addEntriesFromDictionary:options];
    properties[@"url"] = url.absoluteString;
    [self track:@"Deep Link Opened" properties:[properties copy]];
}

- (void)reset
{
    [self run:ByteGainEventTypeReset payload:nil];
}

- (void)flush
{
    [self run:ByteGainEventTypeFlush payload:nil];
}

- (void)enable
{
    _enabled = YES;
}

- (void)disable
{
    _enabled = NO;
}

- (NSString *)getAnonymousId
{
    return [self.integrationsManager getAnonymousId];
}

- (NSDictionary *)bundledIntegrations
{
    return [self.integrationsManager.registeredIntegrations copy];
}

#pragma mark - Class Methods

+ (instancetype)sharedAnalytics
{
    NSCAssert(__sharedInstance != nil, @"library must be initialized before calling this method.");
    return __sharedInstance;
}

+ (void)debug:(BOOL)showDebugLogs
{
    ByteGainSetShowDebugLogs(showDebugLogs);
}

+ (NSString *)version
{
    return @"4.0.1";
}

#pragma mark - Helpers

- (void)run:(ByteGainEventType)eventType payload:(ByteGainPayload *)payload
{
    if (!self.enabled) {
        return;
    }
    ByteGainContext *context = [[[ByteGainContext alloc] initWithAnalytics:self] modify:^(id<ByteGainMutableContext> _Nonnull ctx) {
        ctx.eventType = eventType;
        ctx.payload = payload;
    }];
    // Could probably do more things with callback later, but we don't use it yet.
    [self.runner run:context callback:nil];
}

@end
