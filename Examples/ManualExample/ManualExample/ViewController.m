//
//  ViewController.m
//  ManualExample
//
//  Created by Tony Xiao on 6/30/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Analytics/Analytics.h>
#import "ViewController.h"


@interface ViewController ()

@end


@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[ByteGainAnalytics sharedAnalytics] track:@"Manual Example Main View Loaded"];
    [[ByteGainAnalytics sharedAnalytics] flush];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)fireEvent:(id)sender
{
    [[ByteGainAnalytics sharedAnalytics] track:@"Manual Example Fire Event"];
//    [[ByteGainAnalytics sharedAnalytics] track:@"Manual Example Fire Event dup"];
//    [[ByteGainAnalytics sharedAnalytics] flush];
    [[ByteGainAnalytics sharedAnalytics] attemptGoal:@"multi" makeAttemptCallback:^(NSString * _Nullable variant){
        NSLog(@"multi success callback variant %@", variant);
        [[ByteGainAnalytics sharedAnalytics] reportGoalResult:@"multi" result:ByteGainGoalResultSuccess options:nil];
    } dontMakeAttemptCallback:^{
        NSLog(@"multi failure callback");
    }];
    NSLog(@"Hi MTV!");
}

@end
