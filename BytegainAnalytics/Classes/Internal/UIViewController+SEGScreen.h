#import <UIKit/UIKit.h>


@interface UIViewController (ByteGainScreen)

+ (void)seg_swizzleViewDidAppear;
+ (UIViewController *)seg_topViewController;

@end
