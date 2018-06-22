#import "SEGAttemptGoalPayload.h"

@implementation SEGAttemptGoalPayload


- (instancetype)initWithEvent:(NSString *)event
                   properties:(NSDictionary *)properties
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations
              successCallback:(SEGAttemptGoalSuccessCallback)successCallback
              failureCallback:(SEGAttemptGoalFailureCallback _Nullable)failureCallback
{
    if (self = [super initWithContext:context integrations:integrations]) {
        _event = [event copy];
        _properties = [properties copy];
        _successCallback = [successCallback copy];
        _failureCallback = [failureCallback copy];
    }
    return self;
}

+ (instancetype _Nullable)cast:(id)object {
    return [object isKindOfClass:self] ? object : nil;
}

@end
