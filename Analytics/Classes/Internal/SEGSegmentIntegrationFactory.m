#import "SEGSegmentIntegrationFactory.h"
#import "SEGSegmentIntegration.h"


@implementation ByteGainSegmentIntegrationFactory

- (id)initWithHTTPClient:(ByteGainHTTPClient *)client storage:(id<ByteGainStorage>)storage
{
    if (self = [super init]) {
        _client = client;
        _storage = storage;
    }
    return self;
}

- (id<ByteGainIntegration>)createWithSettings:(NSDictionary *)settings forAnalytics:(ByteGainAnalytics *)analytics
{
    return [[ByteGainSegmentIntegration alloc] initWithAnalytics:analytics httpClient:self.client storage:self.storage];
}

- (NSString *)key
{
    return @"Segment.io";
}

@end
