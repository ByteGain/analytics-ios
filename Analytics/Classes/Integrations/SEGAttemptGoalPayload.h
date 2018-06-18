#import <Foundation/Foundation.h>
#import "SEGPayload.h"

NS_ASSUME_NONNULL_BEGIN


@interface SEGAttemptGoalPayload : SEGPayload

@property (nonatomic, readonly) NSString *event;

@property (nonatomic, readonly, nullable) NSDictionary *properties;

typedef void(^SEGAttemptGoalYesCallback)(NSString * _Nullable);
typedef void(^SEGAttemptGoalNoCallback)(void);

@property (nonatomic, readonly) SEGAttemptGoalYesCallback yesCallback;
@property (nonatomic, readonly, nullable) SEGAttemptGoalNoCallback noCallback;

- (instancetype)initWithEvent:(NSString *)event
                   properties:(NSDictionary *_Nullable)properties
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations
              yesCallback:(SEGAttemptGoalYesCallback) successCallback
              noCallback:(SEGAttemptGoalNoCallback _Nullable) failureCallback;

// Returns object or nil if object is not a SEGAttemptPayload.
+ (instancetype _Nullable)cast:(id)object;

@end

NS_ASSUME_NONNULL_END
