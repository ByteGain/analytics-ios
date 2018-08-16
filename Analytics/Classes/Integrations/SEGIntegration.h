#import <Foundation/Foundation.h>
#import "SEGIdentifyPayload.h"
#import "SEGTrackPayload.h"
#import "SEGAttemptGoalPayload.h"
#import "SEGReportGoalResultPayload.h"
#import "SEGScreenPayload.h"
#import "SEGAliasPayload.h"
#import "SEGIdentifyPayload.h"
#import "SEGGroupPayload.h"
#import "SEGContext.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ByteGainIntegration <NSObject>

@optional
// Identify will be called when the user calls either of the following:
// 1. [[ByteGainAnalytics sharedInstance] identify:someUserId];
// 2. [[ByteGainAnalytics sharedInstance] identify:someUserId traits:someTraits];
// 3. [[ByteGainAnalytics sharedInstance] identify:someUserId traits:someTraits options:someOptions];
// @see https://segment.com/docs/spec/identify/
- (void)identify:(ByteGainIdentifyPayload *)payload;

// Track will be called when the user calls either of the following:
// 1. [[ByteGainAnalytics sharedInstance] track:someEvent];
// 2. [[ByteGainAnalytics sharedInstance] track:someEvent properties:someProperties];
// 3. [[ByteGainAnalytics sharedInstance] track:someEvent properties:someProperties options:someOptions];
// @see https://segment.com/docs/spec/track/
- (void)track:(ByteGainTrackPayload *)payload;

// Screen will be called when the user calls either of the following:
// 1. [[ByteGainAnalytics sharedInstance] screen:someEvent];
// 2. [[ByteGainAnalytics sharedInstance] screen:someEvent properties:someProperties];
// 3. [[ByteGainAnalytics sharedInstance] screen:someEvent properties:someProperties options:someOptions];
// @see https://segment.com/docs/spec/screen/
- (void)screen:(ByteGainScreenPayload *)payload;

// AttemptGoal will be called when the user calls:
// 1. [[ByteGainAnalytics sharedInstance] attemptGoal:...]
- (void)attemptGoal:(ByteGainAttemptGoalPayload *)payload;

- (void)reportGoalResult:(ByteGainReportGoalResultPayload *)payload;

// Group will be called when the user calls either of the following:
// 1. [[ByteGainAnalytics sharedInstance] group:someGroupId];
// 2. [[ByteGainAnalytics sharedInstance] group:someGroupId traits:];
// 3. [[ByteGainAnalytics sharedInstance] group:someGroupId traits:someGroupTraits options:someOptions];
// @see https://segment.com/docs/spec/group/
- (void)group:(ByteGainGroupPayload *)payload;

// Alias will be called when the user calls either of the following:
// 1. [[ByteGainAnalytics sharedInstance] alias:someNewId];
// 2. [[ByteGainAnalytics sharedInstance] alias:someNewId options:someOptions];
// @see https://segment.com/docs/spec/alias/
- (void)alias:(ByteGainAliasPayload *)payload;

// Reset is invoked when the user logs out, and any data saved about the user should be cleared.
- (void)reset;

// Flush is invoked when any queued events should be uploaded.
- (void)flush;

// App Delegate Callbacks

// Callbacks for notifications changes.
// ------------------------------------
- (void)receivedRemoteNotification:(NSDictionary *)userInfo;
- (void)failedToRegisterForRemoteNotificationsWithError:(NSError *)error;
- (void)registeredForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken;
- (void)handleActionWithIdentifier:(NSString *)identifier forRemoteNotification:(NSDictionary *)userInfo;

// Callbacks for app state changes
// -------------------------------

- (void)applicationDidFinishLaunching:(NSNotification *)notification;
- (void)applicationDidEnterBackground;
- (void)applicationWillEnterForeground;
- (void)applicationWillTerminate;
- (void)applicationWillResignActive;
- (void)applicationDidBecomeActive;

- (void)continueUserActivity:(NSUserActivity *)activity;
- (void)openURL:(NSURL *)url options:(NSDictionary *)options;

@end

NS_ASSUME_NONNULL_END
