#import <Foundation/Foundation.h>
#import "SEGPayload.h"

NS_ASSUME_NONNULL_BEGIN


@interface ByteGainAliasPayload : ByteGainPayload

@property (nonatomic, readonly) NSString *theNewId;

- (instancetype)initWithNewId:(NSString *)newId
                      context:(JSON_DICT)context
                 integrations:(JSON_DICT)integrations;

@end

NS_ASSUME_NONNULL_END
