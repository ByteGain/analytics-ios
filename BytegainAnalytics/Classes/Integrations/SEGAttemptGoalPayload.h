#import <Foundation/Foundation.h>
#import "SEGPayload.h"

NS_ASSUME_NONNULL_BEGIN


@interface ByteGainAttemptGoalPayload : ByteGainPayload

@property (nonatomic, readonly) NSString *event;

@property (nonatomic, readonly, nullable) NSDictionary *properties;

typedef void(^ByteGainAttemptGoalYesCallback)(NSString * _Nullable);
typedef void(^ByteGainAttemptGoalNoCallback)(void);

@property (nonatomic, readonly) ByteGainAttemptGoalYesCallback yesCallback;
@property (nonatomic, readonly, nullable) ByteGainAttemptGoalNoCallback noCallback;

- (instancetype)initWithEvent:(NSString *)event
                   properties:(NSDictionary *_Nullable)properties
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations
              yesCallback:(ByteGainAttemptGoalYesCallback) successCallback
              noCallback:(ByteGainAttemptGoalNoCallback _Nullable) failureCallback;

// Returns object or nil if object is not a ByteGainAttemptPayload.
+ (instancetype _Nullable)cast:(id)object;

@end

NS_ASSUME_NONNULL_END
