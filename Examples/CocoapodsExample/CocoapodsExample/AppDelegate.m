//
//  AppDelegate.m
//  CocoapodsExample
//
//  Created by Tony Xiao on 11/28/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <BytegainAnalytics/SEGAnalytics.h>
#import "AppDelegate.h"


@interface AppDelegate ()

@end

#if defined(BG_DEBUG) || defined(POD_CONFIGURATION_BG_DEBUG)
NSString *const BYTEGAIN_WRITE_KEY = @"x7sPb4mmoHBesEwwJIa2XPOAGuSuALwk"; // bgjstest apiKey
#else
#error "Insert your API_KEY below and delete this line"
NSString *const BYTEGAIN_WRITE_KEY = @"YOUR API_KEY GOES HERE";
#endif

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [ByteGainAnalytics debug:YES];
    ByteGainAnalyticsConfiguration *configuration = [ByteGainAnalyticsConfiguration configurationWithWriteKey:BYTEGAIN_WRITE_KEY];
    configuration.trackApplicationLifecycleEvents = YES;
    configuration.trackAttributionData = YES;
    configuration.flushAt = 10;
    [ByteGainAnalytics setupWithConfiguration:configuration];
    [[ByteGainAnalytics sharedAnalytics] track:@"Cocoapods Example Launched"];
    [[ByteGainAnalytics sharedAnalytics] flush];
    NSLog(@"application:didFinishLaunchingWithOptions: %@", launchOptions);
    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application
{
    NSLog(@"applicationWillResignActive:");
}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"applicationDidEnterBackground:");
}


- (void)applicationWillEnterForeground:(UIApplication *)application
{
    NSLog(@"applicationWillEnterForeground:");
}


- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"applicationDidBecomeActive:");
}


- (void)applicationWillTerminate:(UIApplication *)application
{
    NSLog(@"applicationWillTerminate:");
}

@end
