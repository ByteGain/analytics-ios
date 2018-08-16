#import <Foundation/Foundation.h>
#import "SEGSerializableValue.h"

NS_ASSUME_NONNULL_BEGIN


@interface ByteGainPayload : NSObject

@property (nonatomic, readonly) JSON_DICT context;
@property (nonatomic, readonly) JSON_DICT integrations;

- (instancetype)initWithContext:(JSON_DICT)context integrations:(JSON_DICT)integrations;

@end


@interface ByteGainApplicationLifecyclePayload : ByteGainPayload

@property (nonatomic, strong) NSString *notificationName;

// ApplicationDidFinishLaunching only
@property (nonatomic, strong, nullable) NSDictionary *launchOptions;

@end


@interface ByteGainContinueUserActivityPayload : ByteGainPayload

@property (nonatomic, strong) NSUserActivity *activity;

@end


@interface ByteGainOpenURLPayload : ByteGainPayload

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSDictionary *options;

@end

NS_ASSUME_NONNULL_END


@interface ByteGainRemoteNotificationPayload : ByteGainPayload

// ByteGainEventTypeHandleActionWithForRemoteNotification
@property (nonatomic, strong, nullable) NSString *actionIdentifier;

// ByteGainEventTypeHandleActionWithForRemoteNotification
// ByteGainEventTypeReceivedRemoteNotification
@property (nonatomic, strong, nullable) NSDictionary *userInfo;

// ByteGainEventTypeFailedToRegisterForRemoteNotifications
@property (nonatomic, strong, nullable) NSError *error;

// ByteGainEventTypeRegisteredForRemoteNotifications
@property (nonatomic, strong, nullable) NSData *deviceToken;

@end
