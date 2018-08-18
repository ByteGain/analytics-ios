#import <Foundation/Foundation.h>
#import "SEGPayload.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ByteGainGoalResult) {
    ByteGainGoalResultUndefined,     // Not used
    ByteGainGoalResultSuccess,       // Success following a prior attemptGoal
    ByteGainGoalResultFailure,       // Failure following a prior attemptGoal
    ByteGainGoalResultUnsolictedSuccess,  // Accomplishing goal without issuing a prior attemptGoal
};

@interface ByteGainReportGoalResultPayload : ByteGainPayload

@property (nonatomic, readonly) NSString *event;
@property (nonatomic, readonly) ByteGainGoalResult result;

- (instancetype)initWithEvent:(NSString *)event
                       result:(ByteGainGoalResult) result
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations;

@end

NS_ASSUME_NONNULL_END
