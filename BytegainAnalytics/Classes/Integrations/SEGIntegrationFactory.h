#import <Foundation/Foundation.h>
#import "SEGIntegration.h"
#import "SEGAnalytics.h"

NS_ASSUME_NONNULL_BEGIN

@class ByteGainAnalytics;

@protocol ByteGainIntegrationFactory

/**
 * Attempts to create an adapter with the given settings. Returns the adapter if one was created, or null
 * if this factory isn't capable of creating such an adapter.
 */
- (id<ByteGainIntegration>)createWithSettings:(NSDictionary *)settings forAnalytics:(ByteGainAnalytics *)analytics;

/** The key for which this factory can create an Integration. */
- (NSString *)key;

@end

NS_ASSUME_NONNULL_END
