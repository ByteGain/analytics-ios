//
//  ByteGainContext.h
//  Analytics
//
//  Created by Tony Xiao on 9/19/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SEGIntegration.h"

typedef NS_ENUM(NSInteger, ByteGainEventType) {
    // Should not happen, but default state
    ByteGainEventTypeUndefined,
    // Core Tracking Methods
    ByteGainEventTypeIdentify,
    ByteGainEventTypeTrack,
    ByteGainEventTypeScreen,
    ByteGainEventTypeGroup,
    ByteGainEventTypeAlias,

    // General utility
    ByteGainEventTypeReset,
    ByteGainEventTypeFlush,

    // Remote Notification
    ByteGainEventTypeReceivedRemoteNotification,
    ByteGainEventTypeFailedToRegisterForRemoteNotifications,
    ByteGainEventTypeRegisteredForRemoteNotifications,
    ByteGainEventTypeHandleActionWithForRemoteNotification,

    // Application Lifecycle
    ByteGainEventTypeApplicationLifecycle,
    //    DidFinishLaunching,
    //    ByteGainEventTypeApplicationDidEnterBackground,
    //    ByteGainEventTypeApplicationWillEnterForeground,
    //    ByteGainEventTypeApplicationWillTerminate,
    //    ByteGainEventTypeApplicationWillResignActive,
    //    ByteGainEventTypeApplicationDidBecomeActive,

    // Misc.
    ByteGainEventTypeContinueUserActivity,
    ByteGainEventTypeOpenURL,

    // Goals
    ByteGainEventTypeAttemptGoal,
    ByteGainEventTypeReportGoalResult,
};

@class ByteGainAnalytics;
@protocol ByteGainMutableContext;


@interface ByteGainContext : NSObject <NSCopying>

// Loopback reference to the top level ByteGainAnalytics object.
// Not sure if it's a good idea to keep this around in the context.
// since we don't really want people to use it due to the circular
// reference and logic (Thus prefixing with underscore). But
// Right now it is required for integrations to work so I guess we'll leave it in.
@property (nonatomic, readonly, nonnull) ByteGainAnalytics *_analytics;
@property (nonatomic, readonly) ByteGainEventType eventType;

@property (nonatomic, readonly, nullable) NSString *userId;
@property (nonatomic, readonly, nullable) NSString *anonymousId;
@property (nonatomic, readonly, nullable) NSError *error;
@property (nonatomic, readonly, nullable) ByteGainPayload *payload;
@property (nonatomic, readonly) BOOL debug;

- (instancetype _Nonnull)initWithAnalytics:(ByteGainAnalytics *_Nonnull)analytics;

- (ByteGainContext *_Nonnull)modify:(void (^_Nonnull)(id<ByteGainMutableContext> _Nonnull ctx))modify;

@end

@protocol ByteGainMutableContext <NSObject>

@property (nonatomic) ByteGainEventType eventType;
@property (nonatomic, nullable) NSString *userId;
@property (nonatomic, nullable) NSString *anonymousId;
@property (nonatomic, nullable) ByteGainPayload *payload;
@property (nonatomic, nullable) NSError *error;
@property (nonatomic) BOOL debug;

@end
