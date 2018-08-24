//
//  ViewController.m
//  CocoapodsExample
//
//  Created by Tony Xiao on 11/28/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <BytegainAnalytics/SEGAnalytics.h>
// TODO: Test and see if this works
// @import Analytics;
#import "ViewController.h"


@interface ViewController ()

@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSUserActivity *userActivity = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
    userActivity.webpageURL = [NSURL URLWithString:@"http://bytegain.com"];
    [[ByteGainAnalytics sharedAnalytics] continueUserActivity:userActivity];
    [[ByteGainAnalytics sharedAnalytics] track:@"test"];
    [[ByteGainAnalytics sharedAnalytics] flush];
}

- (IBAction)fireEvent:(id)sender
{
    [[ByteGainAnalytics sharedAnalytics] track:@"Cocoapods Example Button"];
    // New call added by ByteGain to attempt a goal
    [[ByteGainAnalytics sharedAnalytics] attemptGoal:@"multi" makeAttemptCallback:^(NSString * _Nullable variant){
        // This block runs when ByteGain says to attempt the goal "multi"
        NSLog(@"multi success callback variant %@", variant);
        // Tell the ByteGain server whether the goal succeeded.
        [[ByteGainAnalytics sharedAnalytics] reportGoalResult:@"multi" result:ByteGainGoalResultSuccess options:nil];
    } dontMakeAttemptCallback:^{
        // This block runs when ByteGain says not to attempt the goal "multi"
        NSLog(@"multi failure callback");
    }];
    //[[ByteGainAnalytics sharedAnalytics] flush];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
