#import <Foundation/Foundation.h>
#import "SEGPayload.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SEGGoalResult) {
    SEGGoalResultUndefined,     // Not used
    SEGGoalResultSuccess,       // Success following a prior attemptGoal
    SEGGoalResultFailure,       // Failure following a prior attemptGoal
    SEGGoalResultUnsolictedSuccess,  // Accomplishing goal without issuing a prior attemptGoal
};

@interface SEGReportGoalResultPayload : SEGPayload

@property (nonatomic, readonly) NSString *event;
@property (nonatomic, readonly) SEGGoalResult result;

- (instancetype)initWithEvent:(NSString *)event
                       result:(SEGGoalResult) result
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations;

@end

NS_ASSUME_NONNULL_END
