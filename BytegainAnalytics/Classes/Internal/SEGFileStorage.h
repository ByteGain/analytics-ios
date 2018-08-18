//
//  ByteGainFileStorage.h
//  Analytics
//
//  Copyright © 2016 Segment. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SEGStorage.h"


@interface ByteGainFileStorage : NSObject <ByteGainStorage>

@property (nonatomic, strong, nullable) id<ByteGainCrypto> crypto;

- (instancetype _Nonnull)init;
- (instancetype _Nonnull)initWithFolder:(NSURL *_Nonnull)folderURL crypto:(id<ByteGainCrypto> _Nullable)crypto;

- (NSURL *_Nonnull)urlForKey:(NSString *_Nonnull)key;

+ (NSURL *_Nullable)applicationSupportDirectoryURL;

@end
