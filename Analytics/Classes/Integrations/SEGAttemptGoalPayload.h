#import <Foundation/Foundation.h>
#import "SEGPayload.h"

NS_ASSUME_NONNULL_BEGIN


@interface SEGAttemptGoalPayload : SEGPayload

@property (nonatomic, readonly) NSString *event;

@property (nonatomic, readonly, nullable) NSDictionary *properties;

typedef void(^SEGAttemptGoalSuccessCallback)(NSString * _Nullable);
typedef void(^SEGAttemptGoalFailureCallback)(void);

@property (nonatomic, readonly) SEGAttemptGoalSuccessCallback successCallback;
@property (nonatomic, readonly, nullable) SEGAttemptGoalFailureCallback failureCallback;

- (instancetype)initWithEvent:(NSString *)event
                   properties:(NSDictionary *_Nullable)properties
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations
              successCallback:(SEGAttemptGoalSuccessCallback) successCallback
              failureCallback:(SEGAttemptGoalFailureCallback _Nullable) failureCallback;

// Returns object or nil if object is not a SEGAttemptPayload.
+ (instancetype _Nullable)cast:(id)object;

@end

NS_ASSUME_NONNULL_END
