#import "SEGReportGoalResultPayload.h"

@implementation ByteGainReportGoalResultPayload

- (instancetype)initWithEvent:(NSString *)event
                       result:(ByteGainGoalResult) result
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations
{
    if (self = [super initWithContext:context integrations:integrations]) {
        _event = [event copy];
        _result = result;
    }
    return self;
}

@end
