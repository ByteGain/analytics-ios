#import "SEGAttemptGoalPayload.h"

@implementation ByteGainAttemptGoalPayload


- (instancetype)initWithEvent:(NSString *)event
                   properties:(NSDictionary *)properties
                      context:(NSDictionary *)context
                 integrations:(NSDictionary *)integrations
              yesCallback:(ByteGainAttemptGoalYesCallback)yesCallback
              noCallback:(ByteGainAttemptGoalNoCallback _Nullable)noCallback
{
    if (self = [super initWithContext:context integrations:integrations]) {
        _event = [event copy];
        _properties = [properties copy];
        _yesCallback = [yesCallback copy];
        _noCallback = [noCallback copy];
    }
    return self;
}

+ (instancetype _Nullable)cast:(id)object {
    return [object isKindOfClass:self] ? object : nil;
}

@end
