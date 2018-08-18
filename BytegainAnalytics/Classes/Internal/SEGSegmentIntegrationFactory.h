#import <Foundation/Foundation.h>
#import "SEGIntegrationFactory.h"
#import "SEGHTTPClient.h"
#import "SEGStorage.h"

NS_ASSUME_NONNULL_BEGIN


@interface ByteGainSegmentIntegrationFactory : NSObject <ByteGainIntegrationFactory>

@property (nonatomic, strong) ByteGainHTTPClient *client;
@property (nonatomic, strong) id<ByteGainStorage> storage;

- (instancetype)initWithHTTPClient:(ByteGainHTTPClient *)client storage:(id<ByteGainStorage>)storage;

@end

NS_ASSUME_NONNULL_END
