//
//  AppDelegate.m
//  ManualExample
//
//  Created by Tony Xiao on 6/30/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Analytics/Analytics.h>
#import "AppDelegate.h"


@interface AppDelegate ()

@end


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // https://segment.com/segment-mobile/sources/ios_manual_example/overview
    // Use your own writekey people :)
#if BG_DEBUG
    [ByteGainAnalytics setupWithConfiguration:[ByteGainAnalyticsConfiguration configurationWithWriteKey:@"x7sPb4mmoHBesEwwJIa2XPOAGuSuALwk"]]; // bgjstest apiKey
#else
#error "Insert your API_KEY below and delete this line"
    [ByteGainAnalytics setupWithConfiguration:[ByteGainAnalyticsConfiguration configurationWithWriteKey:@"YOUR API_KEY GOES HERE"]];
#endif
    [[ByteGainAnalytics sharedAnalytics] track:@"Manual Example Launched"];
    [[ByteGainAnalytics sharedAnalytics] flush];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
