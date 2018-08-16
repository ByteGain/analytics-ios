//
//  ByteGainUserDefaultsStorage.h
//  Analytics
//
//  Created by Tony Xiao on 8/24/16.
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SEGStorage.h"


@interface ByteGainUserDefaultsStorage : NSObject <ByteGainStorage>

@property (nonatomic, strong, nullable) id<ByteGainCrypto> crypto;
@property (nonnull, nonatomic, readonly) NSUserDefaults *defaults;
@property (nullable, nonatomic, readonly) NSString *namespacePrefix;

- (instancetype _Nonnull)initWithDefaults:(NSUserDefaults *_Nonnull)defaults namespacePrefix:(NSString *_Nullable)namespacePrefix crypto:(id<ByteGainCrypto> _Nullable)crypto;

@end
