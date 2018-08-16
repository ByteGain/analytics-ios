#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "SEGAnalytics.h"

NS_ASSUME_NONNULL_BEGIN


@interface ByteGainStoreKitTracker : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>

+ (instancetype)trackTransactionsForAnalytics:(ByteGainAnalytics *)analytics;

@end

NS_ASSUME_NONNULL_END
