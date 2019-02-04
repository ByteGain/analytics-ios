# BytegainAnalytics
[![Version](https://img.shields.io/cocoapods/v/ByteaginAnalytics.svg?style=flat)](https://cocoapods.org//pods/BytegainAnalytics)
[![License](https://img.shields.io/cocoapods/l/BytegainAnalytics.svg?style=flat)](http://cocoapods.org/pods/BytegainAnalytics)
[![codecov](https://codecov.io/gh/segmentio/analytics-ios/branch/master/graph/badge.svg)](https://codecov.io/gh/segmentio/analytics-ios)

bg-analytics-ios is an iOS client for [ByteGain](https://bytegain.com).

## Installation

BytegainAnalytics is available through [CocoaPods](http://cocoapods.org)

### CocoaPods

Add the dependence:
```
pod "BytegainAnalytics", "4.0.2"
```
to your `Podfile`.

## Documentation

The functioning example is in [Examples/CocoapodsExample](./Examples/CocoapodsExample).

Initialization is done in the [Examples/CocoapodsExample/CocoapodsExample/AppDelegate.m](./Examples/CocoapodsExample/CocoapodsExample/AppDelegate.m):
```
    [ByteGainAnalytics debug:YES];
    ByteGainAnalyticsConfiguration *configuration = [ByteGainAnalyticsConfiguration configurationWithWriteKey:BYTEGAIN_API_KEY];
    configuration.trackApplicationLifecycleEvents = YES;
    configuration.trackAttributionData = YES;
    configuration.recordScreenViews = YES;
    configuration.flushAt = 10;
    [ByteGainAnalytics setupWithConfiguration:configuration];
```
The above sets up automatic reporting of screen views and application life cycle events to ByteGain servers.

To send additional event data to ByteGain servers, e.g., button clicks, add calls to the `track` method:
```
- (IBAction)fireEvent:(id)sender
{
    [[ByteGainAnalytics sharedAnalytics] track:@"Cocoapods Example Button"];
```

For more examples, see [Examples/CocoapodsExample/CocoapodsExample/ViewController.m](./Examples/CocoapodsExample/CocoapodsExample/ViewController.m).

The code has been tested for Objective-C apps using XCode v 10.1.
