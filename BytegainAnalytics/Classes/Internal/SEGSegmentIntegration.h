#import <Foundation/Foundation.h>
#import "SEGIntegration.h"
#import "SEGHTTPClient.h"
#import "SEGStorage.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const ByteGainSegmentDidSendRequestNotification;
extern NSString *const ByteGainSegmentRequestDidSucceedNotification;
extern NSString *const ByteGainSegmentRequestDidFailNotification;


@interface ByteGainSegmentIntegration : NSObject <ByteGainIntegration>

- (id)initWithAnalytics:(ByteGainAnalytics *)analytics httpClient:(ByteGainHTTPClient *)httpClient storage:(id<ByteGainStorage>)storage;

@end

NS_ASSUME_NONNULL_END
