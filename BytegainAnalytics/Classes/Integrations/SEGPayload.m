#import "SEGPayload.h"


@implementation ByteGainPayload

- (instancetype)initWithContext:(NSDictionary *)context integrations:(NSDictionary *)integrations
{
    if (self = [super init]) {
        _context = [context copy];
        _integrations = [integrations copy];
    }
    return self;
}

@end


@implementation ByteGainApplicationLifecyclePayload

@end


@implementation ByteGainRemoteNotificationPayload

@end


@implementation ByteGainContinueUserActivityPayload

@end


@implementation ByteGainOpenURLPayload

@end
